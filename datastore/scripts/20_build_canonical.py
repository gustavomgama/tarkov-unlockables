#!/usr/bin/env python3
"""Build the canonical, cross-source Tarkov dataset.

Merges every offlinedata source plus the fetched tarkov.dev localization and
reference endpoints into one record per entity, keyed by the BSG id (the only
identifier common to every source), and writes them as NDJSON under
`canonical/`. Also writes `canonical/reference.json` for the small global
tables and a build report.

Sources:
  tarkovdev/items|tasks|barters|crafts|traders  build/raw game data (no strings)
  tarkovunlockables/*                           derived per-item unlock indexes
  tarkovmarket/items_all                        display names + flea tags
  officialwiki/parsed_items                     wiki page names + infoboxes
  fetched/*_en                                  official display strings
  fetched/maps, fetched/hideout                 map + hideout-station entities

Run: ~/.pyvenv-tarkov/bin/python datastore/scripts/20_build_canonical.py
"""
from __future__ import annotations

import json
import os
import re
from collections import Counter, defaultdict

import _common as C

HEX = re.compile(r"^[0-9a-f]{24}$")

# Flattened stat keys tarkov.dev repeats at the item top level. Kept verbatim
# because they are the only source of these numbers for a few item kinds whose
# `properties` block is absent (ammo packs, some presets).
FLAT_STATS = (
    "damage", "armorClass", "armorDamage", "penetrationPower", "velocity",
    "ergonomicsModifier", "accuracyModifier", "recoilModifier", "recoil",
    "loudness", "maxDurability", "blocksHeadphones", "tracer", "tracerColor",
    "ammoType", "projectileCount", "fragmentationChance", "ricochetChance",
)


# --------------------------------------------------------------------------- #
# load + resolve names
# --------------------------------------------------------------------------- #
def load_all():
    tdev_items = C.load_off("tarkovdev/items.json")["data"]
    raw = {
        "items": tdev_items["items"],
        "item_categories": tdev_items["itemCategories"],
        "handbook_categories": tdev_items["handbookCategories"],
        "flea_market": tdev_items.get("fleaMarket"),
        "armor_materials": tdev_items.get("armorMaterials"),
        "player_levels": tdev_items.get("playerLevels"),
        "mastering": tdev_items.get("mastering"),
        "skills": tdev_items.get("skills"),
        "special_items": tdev_items.get("specialItems"),
        "settings": tdev_items.get("settings"),
    }
    tdev_tasks = C.load_off("tarkovdev/tasks.json")["data"]
    return {
        "raw": raw,
        "tasks": tdev_tasks["tasks"],
        "quest_items": tdev_tasks["questItems"],
        "achievements": tdev_tasks["achievements"],
        "prestige": tdev_tasks.get("prestige"),
        "barters": C.load_off("tarkovdev/barters.json")["data"],
        "crafts": C.load_off("tarkovdev/crafts.json")["data"],
        "traders": C.load_off("tarkovdev/traders.json")["data"],
        "market": C.load_off("tarkovmarket/items_all.json"),
        "index_items": C.load_off("tarkovunlockables/items_index.json"),
        "tasks_index": C.load_off("tarkovunlockables/tasks_index.json"),
        "traders_index": C.load_off("tarkovunlockables/traders_index.json")["traders"],
        "wiki_items": C.load_off("officialwiki/parsed_items.json"),
        "wiki_barters": C.load_off("officialwiki/barter_list.json"),
        "wiki_crafts": C.load_off("officialwiki/craft_list.json"),
        "task_gated_barters": C.load_off("tarkovunlockables/task_gated_barters.json"),
        "task_gated_buyables": C.load_off("tarkovunlockables/task_gated_buyables.json"),
        "task_gated_crafts": C.load_off("tarkovunlockables/task_gated_crafts.json"),
        "en_items": C.load_fetched("items_en")["data"],
        "en_tasks": C.load_fetched("tasks_en")["data"],
        "en_traders": C.load_fetched("traders_en")["data"],
        "en_maps": C.load_fetched("maps_en")["data"],
        "maps": C.load_fetched("maps")["data"].get("maps", {}),
        "hideout": C.load_fetched("hideout")["data"],
        "en_hideout": C.load_fetched("hideout_en")["data"],
    }


def resolve_names(ctx):
    """Fill ctx with id -> display string maps, plus name sources."""
    en = ctx["en_items"]
    wiki = ctx["wiki_items"]
    market = {}
    for m in ctx["market"]:
        if m.get("bsgId"):
            market.setdefault(m["bsgId"], m)
    index = {i["bsg_id"]: i for i in ctx["index_items"] if i.get("bsg_id")}
    ctx["market_by_id"] = market
    ctx["index_by_id"] = index

    names, shorts, descs, srcs = {}, {}, {}, {}
    ids = set(ctx["raw"]["items"]) | set(market) | set(wiki) | set(ctx["quest_items"])
    for i in ids:
        n = en.get(f"{i} Name")
        if n:
            names[i], srcs[i] = n, "tarkovdev:items_en"
            shorts[i] = en.get(f"{i} ShortName")
            descs[i] = en.get(f"{i} Description")
            continue
        w = wiki.get(i)
        if w and w.get("full_name"):
            names[i], srcs[i] = w["full_name"], "officialwiki"
        elif market.get(i, {}).get("name"):
            names[i], srcs[i] = market[i]["name"], "tarkovmarket"
        elif index.get(i, {}).get("full_name"):
            names[i], srcs[i] = index[i]["full_name"], "tarkovunlockables"
        else:
            slug = (ctx["raw"]["items"].get(i) or {}).get("normalizedName") \
                or (ctx["quest_items"].get(i) or {}).get("normalizedName")
            if slug:
                names[i], srcs[i] = C.humanize(slug), "derived:slug"
        if i not in shorts:
            shorts[i] = (market.get(i) or {}).get("shortName") \
                or (index.get(i) or {}).get("short_name")

    ctx["names"], ctx["shorts"], ctx["descs"], ctx["name_src"] = names, shorts, descs, srcs

    # traders ---------------------------------------------------------------
    tnames = {}
    for tid, t in ctx["traders"].items():
        slug = t["normalizedName"]
        tnames[tid] = {
            "id": tid,
            "slug": slug,
            "name": ctx["en_traders"].get(f"{tid} Nickname")
            or (ctx["traders_index"].get(slug) or {}).get("name")
            or C.humanize(slug).title(),
            "description": ctx["en_traders"].get(f"{tid} Description"),
        }
    ctx["trader_by_id"] = tnames

    # maps ------------------------------------------------------------------
    mnames = {}
    for mid, m in ctx["maps"].items():
        mnames[mid] = {
            "id": mid,
            "slug": m.get("normalizedName"),
            "name": ctx["en_maps"].get(f"{mid} Name") or C.wiki_title_name(m.get("wiki")) or C.humanize(m.get("normalizedName")),
        }
    ctx["map_by_id"] = mnames

    # tasks -----------------------------------------------------------------
    tnames = {}
    index_tasks = {}
    for t in ctx["tasks_index"]:
        if t.get("bsg_id"):
            index_tasks[t["bsg_id"]] = t
    for tid, t in ctx["tasks"].items():
        n = ctx["en_tasks"].get(f"{tid} name")
        src = "tarkovdev:tasks_en"
        if not n:
            n = (index_tasks.get(tid) or {}).get("full_name")
            src = "tarkovunlockables"
        if not n:
            n = C.wiki_title_name(t.get("wikiLink"))
            src = "derived:wikiLink"
        tnames[tid] = {"name": n or C.humanize(t.get("normalizedName")), "name_source": src}
    ctx["task_by_id"] = tnames
    ctx["index_task_by_id"] = index_tasks
    ctx["achievements_by_id"] = {
        a["id"]: (ctx["en_tasks"].get(f"{a['id']} name") or C.humanize(a.get("normalizedName")))
        for a in ctx["achievements"].values() if a.get("id")
    }
    return ctx


# --------------------------------------------------------------------------- #
# categories
# --------------------------------------------------------------------------- #
def category_paths(cats, ids):
    out = []
    for cid in ids or []:
        parts, seen, cur = [], set(), cid
        while cur and cur in cats and cur not in seen:
            seen.add(cur)
            parts.append(cats[cur].get("normalizedName"))
            cur = cats[cur].get("parent")
        if parts:
            out.append("/".join(reversed(parts)))
    return out


def build_categories(ctx):
    rows = []
    for kind, cats in (("item", ctx["raw"]["item_categories"]),
                       ("handbook", ctx["raw"]["handbook_categories"])):
        for cid, c in cats.items():
            path = category_paths(cats, [cid])
            rows.append({
                "id": cid,
                "kind": kind,
                "slug": c.get("normalizedName"),
                "parent_id": c.get("parent"),
                "children_ids": c.get("children") or [],
                "path": path[0] if path else c.get("normalizedName"),
                "depth": len(path[0].split("/")) - 1 if path else 0,
                "min_level_for_flea": c.get("minLevelForFlea"),
                "image_url": c.get("imageLink"),
            })
    return rows


# --------------------------------------------------------------------------- #
# traders
# --------------------------------------------------------------------------- #
def build_traders(ctx):
    cats = ctx["raw"]["item_categories"]
    rows = []
    for tid, t in ctx["traders"].items():
        info = ctx["trader_by_id"][tid]
        tasks = [x for x in ctx["tasks"].values() if x.get("trader") == tid]
        rows.append({
            **info,
            "currency": t.get("currency"),
            "reset_time": t.get("resetTime"),
            "discount": t.get("discount"),
            "image_url": t.get("imageLink"),
            "levels": [
                {
                    "id": lv.get("id"),
                    "level": lv.get("level"),
                    "required_player_level": lv.get("requiredPlayerLevel"),
                    "required_reputation": lv.get("requiredReputation"),
                    "required_commerce": lv.get("requiredCommerce"),
                    "pay_rate": lv.get("payRate"),
                    "insurance_rate": lv.get("insuranceRate"),
                    "repair_cost_multiplier": lv.get("repairCostMultiplier"),
                }
                for lv in (t.get("levels") or [])
            ],
            "reputation_levels": t.get("reputationLevels") or [],
            "buy_allowed": {
                "categories": [cats[c]["normalizedName"] for c in (t.get("buyAllowed") or {}).get("category", []) if c in cats],
                "items": [i for i in (t.get("buyAllowed") or {}).get("items", [])],
            },
            "buy_prohibited": {
                "categories": [cats[c]["normalizedName"] for c in (t.get("buyProhibited") or {}).get("category", []) if c in cats],
                "items": [i for i in (t.get("buyProhibited") or {}).get("items", [])],
            },
            "task_count": len(tasks),
        })
    return rows


# --------------------------------------------------------------------------- #
# barters + crafts
# --------------------------------------------------------------------------- #
def item_ref(ctx, bsg_id, count=None):
    """Compact item reference; empty dict when the id is missing so callers
    can always unpack it."""
    if not bsg_id:
        return {}
    r = {"bsg_id": bsg_id, "name": ctx["names"].get(bsg_id)}
    if count is not None:
        r["count"] = count
    return r


def build_barters(ctx):
    rows = []
    for b in ctx["barters"]:
        tid = b.get("trader")
        off = b.get("offeredItem") or {}
        rows.append({
            "id": b.get("id"),
            "trader_id": tid,
            "trader_slug": (ctx["trader_by_id"].get(tid) or {}).get("slug"),
            "trader_name": (ctx["trader_by_id"].get(tid) or {}).get("name"),
            "min_trader_level": b.get("minTraderLevel"),
            "buy_limit": b.get("buyLimit"),
            "restock_amount": b.get("restockAmount"),
            "task_unlock_id": b.get("taskUnlock"),
            "task_unlock_name": (ctx["task_by_id"].get(b.get("taskUnlock")) or {}).get("name"),
            "offered_item": item_ref(ctx, off.get("item"), off.get("count")),
            "required_items": [
                {**item_ref(ctx, ri.get("item"), ri.get("count")), "attributes": ri.get("attributes") or {}}
                for ri in (b.get("requiredItems") or [])
            ],
        })
    return rows


def build_crafts(ctx):
    st_names = station_names(ctx)
    rows = []
    for c in ctx["crafts"]:
        sid = c.get("station")
        prod = c.get("productItem") or {}
        rows.append({
            "id": c.get("id"),
            "station_id": sid,
            "station_slug": st_names.get(sid, {}).get("slug"),
            "station_name": st_names.get(sid, {}).get("name"),
            "level": c.get("level"),
            "duration": c.get("duration"),
            "duration_seconds": c.get("duration"),
            "game_editions": c.get("gameEditions") or [],
            "task_unlock_id": c.get("taskUnlock"),
            "task_unlock_name": (ctx["task_by_id"].get(c.get("taskUnlock")) or {}).get("name"),
            "product_item": item_ref(ctx, prod.get("item"), prod.get("count")),
            "required_items": [
                {**item_ref(ctx, ri.get("item"), ri.get("count")), "is_tool": bool((ri.get("attributes") or {}).get("tool"))}
                for ri in (c.get("requiredItems") or [])
            ],
            "required_quest_items": [item_ref(ctx, ri.get("item"), ri.get("count")) for ri in (c.get("requiredQuestItems") or [])],
        })
    return rows


def station_names(ctx):
    """Map hideout station id -> display name. Ids come from fetched/hideout."""
    if "_station_names" in ctx:
        return ctx["_station_names"]
    out = {}
    for sid, st in ctx["hideout"].items():
        name = ctx["en_hideout"].get(st.get("name")) or C.humanize(st.get("normalizedName"))
        out[sid] = {"id": sid, "slug": st.get("normalizedName"), "name": name}
    ctx["_station_names"] = out
    return out


# --------------------------------------------------------------------------- #
# tasks
# --------------------------------------------------------------------------- #
def resolve_ids(ctx, obj):
    """Map every 24-hex id inside a nested structure to a display string."""
    found = {}

    def walk(v):
        if isinstance(v, dict):
            for x in v.values():
                walk(x)
        elif isinstance(v, list):
            for x in v:
                walk(x)
        elif isinstance(v, str) and HEX.match(v):
            if v in found:
                return
            found[v] = ctx["names"].get(v) or (ctx["trader_by_id"].get(v) or {}).get("slug") \
                or (ctx["map_by_id"].get(v) or {}).get("name") or (ctx["task_by_id"].get(v) or {}).get("name")
    walk(obj)
    return {k: n for k, n in found.items() if n}


def task_req_ref(ctx, req):
    """A taskRequirements entry is {task:{id,name}, status:[...]} — normalize it."""
    raw = req.get("task")
    if isinstance(raw, dict):
        return {"bsg_id": raw.get("id"), "name": ctx["task_by_id"].get(raw.get("id"), {}).get("name") or raw.get("name")}
    if raw:
        return {"bsg_id": raw, "name": ctx["task_by_id"].get(raw, {}).get("name")}
    return {}


def build_tasks(ctx):
    rows = []
    for tid, t in ctx["tasks"].items():
        tid_trader = t.get("trader")
        index = ctx["index_task_by_id"].get(tid) or {}
        objectives = []
        for o in t.get("objectives") or []:
            objectives.append({
                "id": o.get("id"),
                "type": o.get("type"),
                "description": ctx["en_tasks"].get(o.get("id")) or ctx["en_tasks"].get(o.get("description") or ""),
                "optional": o.get("optional"),
                "count": o.get("count"),
                "raw": o,
                "id_names": resolve_ids(ctx, o),
            })
        # map: task-level, else the most common map on the objectives
        map_id = t.get("map")
        if not map_id:
            votes = Counter()
            for o in t.get("objectives") or []:
                for m in (o.get("maps") or []):
                    votes[m] += 1
            if votes:
                map_id = votes.most_common(1)[0][0]
        rows.append({
            "id": tid,
            "slug": t.get("normalizedName"),
            "name": ctx["task_by_id"].get(tid, {}).get("name"),
            "name_source": ctx["task_by_id"].get(tid, {}).get("name_source"),
            "wiki_link": t.get("wikiLink"),
            "trader_id": tid_trader,
            "trader_slug": (ctx["trader_by_id"].get(tid_trader) or {}).get("slug"),
            "trader_name": (ctx["trader_by_id"].get(tid_trader) or {}).get("name"),
            "map_id": map_id,
            "map_name": (ctx["map_by_id"].get(map_id) or {}).get("name"),
            "min_player_level": t.get("minPlayerLevel"),
            "experience": t.get("experience"),
            "faction": t.get("factionName"),
            "kappa_required": t.get("kappaRequired"),
            "lightkeeper_required": t.get("lightkeeperRequired"),
            "restartable": t.get("restartable"),
            "required_prestige": t.get("requiredPrestige"),
            "game_mode": t.get("gameMode") or [],
            "available_delay_seconds": {
                "min": t.get("availableDelaySecondsMin"),
                "max": t.get("availableDelaySecondsMax"),
            },
            "task_requirements": [x for x in (task_req_ref(ctx, r) for r in (t.get("taskRequirements") or [])) if x],
            "trader_requirements": [
                {
                    "trader_id": r.get("trader"),
                    "trader_slug": (ctx["trader_by_id"].get(r.get("trader")) or {}).get("slug"),
                    "requirement_type": r.get("requirementType"),
                    "compare_method": r.get("compareMethod"),
                    "value": r.get("value"),
                }
                for r in (t.get("traderRequirements") or [])
            ],
            "other_requirements": t.get("otherRequirements") or [],
            "objectives": objectives,
            "fail_conditions": t.get("failConditions") or [],
            "needed_keys": [
                {
                    "map_id": nk.get("map"),
                    "map_name": (ctx["map_by_id"].get(nk.get("map")) or {}).get("name"),
                    "keys": [item_ref(ctx, k) for k in (nk.get("keys") or [])],
                }
                for nk in (t.get("neededKeys") or [])
            ],
            "start_rewards": reward_block(ctx, t.get("startRewards")),
            "finish_rewards": reward_block(ctx, t.get("finishRewards")),
            "failure_outcome": reward_block(ctx, t.get("failureOutcome")),
            "leads_to": [
                {
                    "task_id": lt.get("task_id"),
                    "task_name": lt.get("task_name") or (ctx["task_by_id"].get(lt.get("task_id")) or {}).get("name"),
                }
                for lt in (index.get("leads_to") or [])
            ],
            "previous_tasks": unique(
                pt.get("task_id")
                for req in (index.get("requirements") or [])
                for pt in (req.get("previous_tasks") or [])
            ),
            "task_image_url": t.get("taskImageLink"),
        })
    return rows


def unique(seq):
    out, seen = [], set()
    for x in seq:
        if x and x not in seen:
            seen.add(x)
            out.append(x)
    return out


def reward_block(ctx, block):
    block = block or {}
    items = [
        {**item_ref(ctx, i.get("item"), i.get("count")), "attributes": i.get("attributes") or {}}
        for i in (block.get("items") or [])
    ]
    return {
        "items": items,
        "trader_standing": [
            {
                "trader_id": s.get("trader"),
                "trader_slug": (ctx["trader_by_id"].get(s.get("trader")) or {}).get("slug"),
                "standing": s.get("standing"),
            }
            for s in (block.get("traderStanding") or [])
        ],
        "offer_unlock": [
            {
                **item_ref(ctx, o.get("item"), o.get("count")),
                "unlock_id": o.get("id"),
                "trader_id": o.get("trader"),
                "trader_slug": (ctx["trader_by_id"].get(o.get("trader")) or {}).get("slug"),
                "level": o.get("level"),
            }
            for o in (block.get("offerUnlock") or [])
        ],
        "craft_unlock": [
            {
                **item_ref(ctx, c.get("item"), c.get("count")),
                "station_id": c.get("station"),
                "station_name": (station_names(ctx).get(c.get("station")) or {}).get("name"),
                "level": c.get("level"),
            }
            for c in (block.get("craftUnlock") or [])
        ],
        "trader_unlock": [
            {
                "trader_id": tid,
                "trader_slug": (ctx["trader_by_id"].get(tid) or {}).get("slug"),
                "trader_name": (ctx["trader_by_id"].get(tid) or {}).get("name"),
            }
            for tid in trader_ids(block.get("traderUnlock"))
        ],
        "skill_level_reward": block.get("skillLevelReward") or [],
        "achievement": [
            {"id": aid, "name": ctx["en_tasks"].get(aid) or (ctx.get("achievements_by_id") or {}).get(aid)}
            for aid in trader_ids(block.get("achievement"))
        ],
        "customization": [
            {k: c.get(k) for k in ("id", "customizationType")} for c in (block.get("customization") or [])
        ],
        "location_unlock": [
            {"map_id": m, "map_name": (ctx["map_by_id"].get(m) or {}).get("name")}
            for m in trader_ids(block.get("locationUnlock"))
        ],
        "trader_dialogue_unlock": [
            {"trader_id": tid, "trader_slug": (ctx["trader_by_id"].get(tid) or {}).get("slug")}
            for tid in trader_ids(block.get("traderDialogueUnlock"))
        ],
    }


def trader_ids(value):
    """Reward lists can hold bare id strings or objects with .trader/.id."""
    out = []
    for v in value or []:
        if isinstance(v, str):
            out.append(v)
        elif isinstance(v, dict):
            out.append(v.get("trader") or v.get("id"))
    return [x for x in out if x]


# --------------------------------------------------------------------------- #
# maps + hideout
# --------------------------------------------------------------------------- #
def build_maps(ctx):
    en = ctx["en_maps"]

    def loc(key):
        if not key:
            return None
        return en.get(key) or C.humanize(key)

    def mobs(entries):
        """escorts/supports are [{mob, amount:[{chance,count}]}]."""
        return [
            {
                "mob": e.get("mob"),
                "name": loc(e.get("mob")),
                "amount": [{"chance": a.get("chance"), "count": a.get("count")} for a in (e.get("amount") or [])],
            }
            for e in (entries or [])
            if isinstance(e, dict)
        ]

    rows = []
    for mid, m in ctx["maps"].items():
        info = ctx["map_by_id"][mid]
        rows.append({
            **info,
            "name_id": m.get("nameId"),
            "wiki_link": m.get("wiki"),
            "description": en.get(f"{mid} Description"),
            "raid_duration": m.get("raidDuration"),
            "players": m.get("players"),
            "enemies": [{"id": e, "name": loc(e)} for e in (m.get("enemies") or [])],
            "bosses": [
                {
                    "mob": b.get("mob"),
                    "name": loc(b.get("mob")),
                    "spawn_chance": b.get("spawnChance"),
                    "escorts": mobs(b.get("escorts")),
                    "supports": mobs(b.get("supports")),
                }
                for b in (m.get("bosses") or [])
            ],
            "extracts": [
                {"id": e.get("id"), "name": loc(e.get("name")), "faction": e.get("faction")}
                for e in (m.get("extracts") or [])
            ],
            "transits": [
                {
                    "id": t.get("id"),
                    "name": loc(t.get("description")),
                    "map_id": t.get("map"),
                    "map_name": (ctx["map_by_id"].get(t.get("map")) or {}).get("name"),
                }
                for t in (m.get("transits") or [])
            ],
        })
    return rows


def build_hideout(ctx):
    rows = []
    for sid, st in ctx["hideout"].items():
        info = station_names(ctx).get(sid, {})
        levels = []
        for lv in st.get("levels") or []:
            levels.append({
                "id": lv.get("id"),
                "level": lv.get("level"),
                "construction_time": lv.get("constructionTime"),
                "item_requirements": [
                    {**item_ref(ctx, ir.get("item"), ir.get("count")), "found_in_raid": bool((ir.get("attributes") or {}).get("foundInRaid"))}
                    for ir in (lv.get("itemRequirements") or [])
                ],
                "station_level_requirements": [
                    {
                        "station_id": sr.get("station"),
                        "station_name": station_names(ctx).get(sr.get("station"), {}).get("name"),
                        "level": sr.get("level"),
                    }
                    for sr in (lv.get("stationLevelRequirements") or [])
                ],
                "trader_requirements": [
                    {
                        "trader_id": tr.get("trader"),
                        "trader_slug": (ctx["trader_by_id"].get(tr.get("trader")) or {}).get("slug"),
                        "level": tr.get("level"),
                    }
                    for tr in (lv.get("traderRequirements") or [])
                ],
            })
        rows.append({**info, "area_type": st.get("areaType"), "image_url": st.get("imageLink"), "levels": levels})
    return rows


# --------------------------------------------------------------------------- #
# items
# --------------------------------------------------------------------------- #
def buy_routes(ctx, it):
    """Currency purchase routes from tarkovdev.

    Authoritative and priced, but present on 2,598 items. The derived
    unlockables index claims 2,965 and — importantly — its entries carry a
    `variant` label, because a trader "buying" a base weapon is really offering
    preset variants of it. The two are kept apart as `buy` and `index_offers`
    instead of merged, so neither semantics is invented away.
    """
    rows = []
    for b in it.get("buyFromTrader") or []:
        rows.append({
            "trader_id": b.get("trader"),
            "trader_slug": (ctx["trader_by_id"].get(b.get("trader")) or {}).get("slug"),
            "currency": b.get("currency"),
            "min_trader_level": b.get("minTraderLevel"),
            "price": b.get("price"),
            "price_rub": b.get("priceRUB"),
            "task_unlock_id": b.get("taskUnlock"),
            "buy_limit": b.get("buyLimit"),
            "source": "tarkovdev",
        })
    return rows


def index_offers(ctx, ob):
    """The derived index's currency claims: trader, loyalty, currency, variant."""
    rows = []
    for c in ob.get("currency") or []:
        slug = (c.get("trader_name") or "").strip().lower().replace("_", "-") or None
        rows.append({
            "trader_slug": slug,
            "currency": c.get("currency"),
            "level": c.get("trader_level"),
            "variant": c.get("variant"),
            "source": "tarkovunlockables",
        })
    return rows


def build_items(ctx):
    raw_items = ctx["raw"]["items"]
    quest_items = ctx["quest_items"]
    index = ctx["index_by_id"]
    wiki = ctx["wiki_items"]
    en = ctx["en_items"]
    cats = ctx["raw"]["item_categories"]
    hcats = ctx["raw"]["handbook_categories"]

    # --- forward/reverse acquisition prepasses ---------------------------
    barter_by_offered = defaultdict(list)
    barter_uses = defaultdict(list)
    for b in ctx["barters"]:
        off = (b.get("offeredItem") or {}).get("item")
        if off:
            barter_by_offered[off].append(b)
        for ri in b.get("requiredItems") or []:
            if ri.get("item"):
                barter_uses[ri["item"]].append(b)

    craft_by_product = defaultdict(list)
    craft_uses = defaultdict(list)
    for c in ctx["crafts"]:
        prod = (c.get("productItem") or {}).get("item")
        if prod:
            craft_by_product[prod].append(c)
        for ri in c.get("requiredItems") or []:
            if ri.get("item"):
                craft_uses[ri["item"]].append(c)

    reward_items = defaultdict(list)
    for tid, t in ctx["tasks"].items():
        for phase, block in (("start", t.get("startRewards")), ("finish", t.get("finishRewards"))):
            for i in ((block or {}).get("items") or []):
                if i.get("item"):
                    reward_items[i["item"]].append({
                        "task_id": tid,
                        "task_name": ctx["task_by_id"].get(tid, {}).get("name"),
                        "phase": phase,
                        "count": i.get("count"),
                    })

    objective_uses = defaultdict(list)
    for tid, t in ctx["tasks"].items():
        for o in t.get("objectives") or []:
            for i in (o.get("items") or []):
                objective_uses[i].append({"task_id": tid, "task_name": ctx["task_by_id"].get(tid, {}).get("name"), "type": o.get("type")})
            qi = o.get("questItem")
            if qi:
                objective_uses[qi].append({"task_id": tid, "task_name": ctx["task_by_id"].get(tid, {}).get("name"), "type": o.get("type")})

    station = station_names(ctx)
    hideout_uses = defaultdict(list)
    for st in build_hideout(ctx):
        for lv in st["levels"]:
            for ir in lv["item_requirements"]:
                if ir["bsg_id"]:
                    hideout_uses[ir["bsg_id"]].append({
                        "station_id": st["id"], "station_name": st["name"],
                        "level": lv["level"], "count": ir["count"], "found_in_raid": ir["found_in_raid"],
                    })

    # --- one row per id --------------------------------------------------
    ids = sorted(set(raw_items) | set(ctx["market_by_id"]) | set(wiki) | set(quest_items))
    for i in ids:
        it = raw_items.get(i) or {}
        props = it.get("properties") or {}
        pt = props.get("propertiesType") if props else None
        idx = index.get(i) or {}
        w = wiki.get(i) or {}
        mk = ctx["market_by_id"].get(i) or {}
        ob = (idx.get("obtain_from") or [{}])
        ob = ob[0] if ob else {}

        sources = []
        if i in raw_items:
            sources.append("tarkovdev")
        if i in ctx["market_by_id"]:
            sources.append("tarkovmarket")
        if i in wiki:
            sources.append("officialwiki")
        if i in index:
            sources.append("tarkovunlockables")
        if i in quest_items:
            sources.append("tarkovdev:questItems")

        yield _item_row(ctx, i, it, props, pt, idx, w, mk, ob, cats, hcats, en, station,
                        barter_by_offered, barter_uses, craft_by_product, craft_uses,
                        reward_items, objective_uses, hideout_uses, sources)


def _item_row(ctx, i, it, props, pt, idx, w, mk, ob, cats, hcats, en, station,
              barter_by_offered, barter_uses, craft_by_product, craft_uses,
              reward_items, objective_uses, hideout_uses, sources):
    def bref(b):
        off = b.get("offeredItem") or {}
        return {
            "barter_id": b.get("id"),
            "trader_slug": (ctx["trader_by_id"].get(b.get("trader")) or {}).get("slug"),
            "min_trader_level": b.get("minTraderLevel"),
            "buy_limit": b.get("buyLimit"),
            "restock_amount": b.get("restockAmount"),
            "task_unlock_id": b.get("taskUnlock"),
            "offered": {"bsg_id": off.get("item"), "name": ctx["names"].get(off.get("item")), "count": off.get("count")},
            "required": [{"bsg_id": ri.get("item"), "name": ctx["names"].get(ri.get("item")), "count": ri.get("count")} for ri in (b.get("requiredItems") or [])],
        }

    def cref(c):
        prod = c.get("productItem") or {}
        return {
            "craft_id": c.get("id"),
            "station_id": c.get("station"),
            "station_name": (station.get(c.get("station")) or {}).get("name"),
            "level": c.get("level"),
            "duration": c.get("duration"),
            "task_unlock_id": c.get("taskUnlock"),
            "product": {"bsg_id": prod.get("item"), "name": ctx["names"].get(prod.get("item")), "count": prod.get("count")},
            "required": [
                {"bsg_id": ri.get("item"), "name": ctx["names"].get(ri.get("item")), "count": ri.get("count"), "is_tool": bool((ri.get("attributes") or {}).get("tool"))}
                for ri in (c.get("requiredItems") or [])
            ],
        }

    category_ids = it.get("categories") or []
    handbook_ids = it.get("handbookCategories") or []
    return {
        "bsg_id": i,
        "slug": it.get("normalizedName") or (ctx["quest_items"].get(i) or {}).get("normalizedName")
        or idx.get("slug") or C.slugify(ctx["names"].get(i)),
        "name": ctx["names"].get(i),
        "short_name": ctx["shorts"].get(i),
        "description": ctx["descs"].get(i),
        "name_source": ctx["name_src"].get(i),
        "quest_item": i in ctx["quest_items"],
        "types": it.get("types") or [],
        "categories": {
            "ids": category_ids,
            "leaves": [cats[c]["normalizedName"] for c in category_ids if c in cats],
            "paths": category_paths(cats, category_ids),
        },
        "handbook_categories": {
            "ids": handbook_ids,
            "leaves": [hcats[c]["normalizedName"] for c in handbook_ids if c in hcats],
            "paths": category_paths(hcats, handbook_ids),
        },
        "properties_type": pt,
        "properties": props,
        "slots": [
            {
                "id": s.get("id"),
                "name_id": s.get("nameId"),
                "name": en.get((s.get("nameId") or "").upper()),
                "required": s.get("required"),
                "filters": {
                    "allowed_items": (s.get("filters") or {}).get("allowedItems") or [],
                    "allowed_categories": (s.get("filters") or {}).get("allowedCategories") or [],
                    "excluded_items": (s.get("filters") or {}).get("excludedItems") or [],
                    "excluded_categories": (s.get("filters") or {}).get("excludedCategories") or [],
                },
            }
            for s in (props.get("slots") or [])
        ],
        "grids": [
            {
                "width": g.get("width"),
                "height": g.get("height"),
                "allowed_categories": (g.get("filters") or {}).get("allowedCategories") or [],
                "allowed_items": (g.get("filters") or {}).get("allowedItems") or [],
                "excluded_categories": (g.get("filters") or {}).get("excludedCategories") or [],
            }
            for g in (props.get("grids") or [])
        ],
        "stats": {k: it[k] for k in FLAT_STATS if it.get(k) is not None},
        "physical": {
            "width": it.get("width"),
            "height": it.get("height"),
            "weight": it.get("weight"),
            "stack_max_size": it.get("stackMaxSize"),
            "has_grid": it.get("hasGrid"),
            "background_color": it.get("backgroundColor"),
            "discard_limit": it.get("discardLimit"),
        },
        "economy": {
            "base_price": it.get("basePrice"),
            "last_low_price": it.get("lastLowPrice"),
            "avg24h_price": it.get("avg24hPrice"),
            "low24h_price": it.get("low24hPrice"),
            "high24h_price": it.get("high24hPrice"),
            "change_last_48h": it.get("changeLast48h"),
            "change_last_48h_percent": it.get("changeLast48hPercent"),
            "last_offer_count": it.get("lastOfferCount"),
            "min_level_for_flea": it.get("minLevelForFlea"),
            "last_scan": it.get("lastScan"),
        },
        "trade": {
            "buy_from": [
                {
                    "trader_id": b.get("trader"),
                    "trader_slug": (ctx["trader_by_id"].get(b.get("trader")) or {}).get("slug"),
                    "price": b.get("price"),
                    "price_rub": b.get("priceRUB"),
                    "currency": b.get("currency"),
                    "currency_item": b.get("currencyItem"),
                    "min_trader_level": b.get("minTraderLevel"),
                    "task_unlock_id": b.get("taskUnlock"),
                    "buy_limit": b.get("buyLimit"),
                }
                for b in (it.get("buyFromTrader") or [])
            ],
            "sell_to": [
                {
                    "trader_id": b.get("trader"),
                    "trader_slug": (ctx["trader_by_id"].get(b.get("trader")) or {}).get("slug"),
                    "price": b.get("price"),
                    "price_rub": b.get("priceRUB"),
                    "currency": b.get("currency"),
                }
                for b in (it.get("sellToTrader") or [])
            ],
        },
        "contains_items": [
            {"bsg_id": ci.get("item"), "name": ctx["names"].get(ci.get("item")), "count": ci.get("count")}
            for ci in (it.get("containsItems") or [])
        ],
        "conflicts": {
            "items": it.get("conflictingItems") or [],
            "slot_ids": it.get("conflictingSlotIds") or [],
            "categories": it.get("conflictingCategories") or [],
        },
        "images": {
            "icon": it.get("iconLink"),
            "grid": it.get("gridImageLink"),
            "base": it.get("baseImageLink"),
            "inspect": it.get("inspectImageLink"),
            "image512": it.get("image512pxLink"),
            "image8x": it.get("image8xLink"),
            "market": mk.get("img"),
            "market_big": mk.get("imgBig"),
        },
        "links": {
            "tarkovdev": it.get("link"),
            "wiki": it.get("wikiLink"),
            "market": mk.get("link"),
        },
        "wiki": ({
            "title": w.get("full_name"),
            "infobox": w.get("infobox") or {},
            "mod_slots": (w.get("sections") or {}).get("mods") or [],
            "weapon_variants": (w.get("sections") or {}).get("weapon_variants") or [],
        } if w else None),
        "market": ({"uid": mk.get("uid"), "tags": mk.get("tags") or [], "name": mk.get("name"), "short_name": mk.get("shortName")} if mk else None),
        "acquisition": {
            "buy": buy_routes(ctx, it),
            "index_offers": index_offers(ctx, ob),
            "barter": [bref(b) for b in barter_by_offered.get(i, [])],
            "craft": [cref(c) for c in craft_by_product.get(i, [])],
            "task_rewards": reward_items.get(i, []),
        },
        "used_in": {
            "crafts": [cref(c) for c in craft_uses.get(i, [])],
            "barters": [bref(b) for b in barter_uses.get(i, [])],
            "hideout_build": hideout_uses.get(i, []),
            "task_objectives": objective_uses.get(i, []),
        },
        "sources": sources,
    }


# --------------------------------------------------------------------------- #
# reference + report
# --------------------------------------------------------------------------- #
def build_reference(ctx):
    return {
        "generated_from": {
            "offlinedata": "tarkovdev (2026-09-03 dump), tarkovunlockables, tarkovmarket, officialwiki",
            "fetched": "json.tarkov.dev/regular localized + reference endpoints (see fetched/manifest.json)",
        },
        "flea_market": ctx["raw"]["flea_market"],
        "armor_materials": ctx["raw"]["armor_materials"],
        "player_levels": ctx["raw"]["player_levels"],
        "skills": ctx["raw"]["skills"],
        "mastering": ctx["raw"]["mastering"],
        "special_items": ctx["raw"]["special_items"],
        "settings": ctx["raw"]["settings"],
        "prestige": ctx["prestige"],
        "achievements": [
            {
                "id": a.get("id"),
                "name": ctx["achievements_by_id"].get(a.get("id")),
                "slug": a.get("normalizedName"),
                "description": ctx["en_tasks"].get(f"{a.get('id')} description"),
                "hidden": a.get("hidden"),
                "side": a.get("side"),
                "rarity": a.get("normalizedRarity"),
                "players_completed_percent": a.get("playersCompletedPercent"),
                "image_url": a.get("imageLink"),
            }
            for a in ctx["achievements"].values()
        ],
    }

def main():
    ctx = resolve_names(load_all())
    os.makedirs(C.CANON, exist_ok=True)

    stats = {}
    stats["categories"] = C.write_jsonl(os.path.join(C.CANON, "categories.ndjson"), build_categories(ctx))
    stats["traders"] = C.write_jsonl(os.path.join(C.CANON, "traders.ndjson"), build_traders(ctx))
    stats["barters"] = C.write_jsonl(os.path.join(C.CANON, "barters.ndjson"), build_barters(ctx))
    stats["crafts"] = C.write_jsonl(os.path.join(C.CANON, "crafts.ndjson"), build_crafts(ctx))
    tasks = build_tasks(ctx)
    stats["tasks"] = C.write_jsonl(os.path.join(C.CANON, "tasks.ndjson"), tasks)
    stats["maps"] = C.write_jsonl(os.path.join(C.CANON, "maps.ndjson"), build_maps(ctx))
    stats["hideout_stations"] = C.write_jsonl(os.path.join(C.CANON, "hideout_stations.ndjson"), build_hideout(ctx))
    stats["items"] = C.write_jsonl(os.path.join(C.CANON, "items.ndjson"), build_items(ctx))

    with open(os.path.join(C.CANON, "reference.json"), "w", encoding="utf-8") as fh:
        json.dump(build_reference(ctx), fh, ensure_ascii=False, indent=1)

    name_src = Counter(ctx["name_src"].values())
    lines = ["# Canonical build", "", "| entity | rows |", "| --- | ---: |"]
    lines += [f"| {k} | {v} |" for k, v in stats.items()]
    lines += ["", "## Item display-name provenance", "", "| source | items |", "| --- | ---: |"]
    lines += [f"| {k} | {v} |" for k, v in name_src.most_common()]
    lines += ["", "## File sizes", ""]
    for f in sorted(os.listdir(C.CANON)):
        p = os.path.join(C.CANON, f)
        lines.append(f"- `{f}` — {os.path.getsize(p) / 1e6:.1f} MB")
    os.makedirs(C.REPORTS, exist_ok=True)
    with open(os.path.join(C.REPORTS, "02_build_stats.md"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
    print("\n".join(lines))


if __name__ == "__main__":
    main()
