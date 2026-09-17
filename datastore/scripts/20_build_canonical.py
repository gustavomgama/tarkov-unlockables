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

import glob
import json
import os
import re
from collections import Counter, defaultdict

import mwparserfromhell

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
def expand_wiki_items(parsed):
    """Give every BSG id on a wiki page the page's parsed data.

    156 of the 3,901 item infoboxes list **several** `node` ids — colour
    variants (Taupe/Red/FDE), "ammo pack (120 pcs)" bundles, and PvE/PvP
    duplicates of one item. `parsed_items.json` only keeps the page's first
    node, which leaves 215 canonical items with a wiki page but no wiki block
    (so they lose the wiki-only joins: mod slots, builds, trader offers,
    conflicts). Re-parse the raw batches and clone the entry onto every id the
    infobox names.

    Returns (parsed, added) via a wrapper so the caller keeps a plain dict; the
    added count is recorded for the build report.
    """
    by_title = {v.get("full_name"): v for v in parsed.values() if v.get("full_name")}
    EXPANSION["pages"] = 0
    EXPANSION["ids"] = 0
    batches = sorted(glob.glob(os.path.join(
        os.path.dirname(_common_dir()), "offlinedata", "officialwiki", "itembatches", "*.json")))
    added = 0
    for path in batches:
        with open(path, encoding="utf-8") as fh:
            pages = json.load(fh)["query"]["pages"]
        for pg in pages:
            revision = (pg.get("revisions") or [{}])[0]
            content = ((revision.get("slots") or {}).get("main") or {}).get("content")
            if not content:
                continue
            entry = by_title.get(pg.get("title"))
            if entry is None:
                continue
            for tpl in mwparserfromhell.parse(content).filter_templates():
                if not str(tpl.name).strip().lower().startswith("infobox") or not tpl.has("node"):
                    continue
                ids = re.findall(r"\b[0-9a-f]{24}\b", str(tpl.get("node").value))
                if len(ids) < 2:
                    continue
                if any(extra not in parsed for extra in ids):
                    EXPANSION["pages"] += 1
                for extra in ids:
                    if extra not in parsed:
                        parsed[extra] = dict(entry)
                        added += 1
    EXPANSION["ids"] = added
    return parsed


def _common_dir():
    return C.DS


# filled in by expand_wiki_items: how many extra ids a wiki page lent its data to
EXPANSION = {}


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
        "wiki_items": expand_wiki_items(C.load_off("officialwiki/parsed_items.json")),
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
    """Fill ctx with id -> display string maps, plus name sources.

    Two localization sources matter for items: `items_en` covers the 5,312
    main items, but quest items are absent from `/items` and are localized in
    `tasks_en` instead (all 135 carry `<id> Name` / `ShortName` / `Description`
    there).
    """
    en = ctx["en_items"]
    en_tasks = ctx["en_tasks"]
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
        n = en_tasks.get(f"{i} Name")
        if n:
            names[i], srcs[i] = n, "tarkovdev:tasks_en"
            shorts[i] = en_tasks.get(f"{i} ShortName")
            descs[i] = en_tasks.get(f"{i} Description")
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


def _wiki_previous_links(value):
    """[(quest name, is_alternative), ...] from a wiki `previous = ...` value.

    Wikilinks joined by `or` are alternatives — the player needs any one of
    them, not all — while adjacent links are all required. Every member of an
    `or` group is an alternative, the first one included.
    """
    tokens = []
    for node in mwparserfromhell.parse(value).nodes:
        if isinstance(node, mwparserfromhell.nodes.Wikilink):
            title = str(node.title).strip()
            # "Fail X" means X is the quest you must not fail.
            if title.lower().startswith("fail "):
                title = title[5:].strip()
            if title:
                tokens.append(("link", title))
        elif isinstance(node, mwparserfromhell.nodes.Text) and str(node).strip().lower() == "or":
            tokens.append(("or",))

    out = []
    for i, token in enumerate(tokens):
        if token[0] != "link":
            continue
        before = tokens[i - 1][0] == "or" if i > 0 else False
        after = tokens[i + 1][0] == "or" if i + 1 < len(tokens) else False
        out.append((token[1], before or after))
    return out


def wiki_task_previous():
    """Wiki quest name -> [(previous quest name, is_alternative), ...].

    The wiki lists every prerequisite, where the API's `taskRequirements`
    often carries only the immediate one, so this is the fuller edge set.
    Parsed with mwparserfromhell: the page is heading-delimited wikitext (not a
    template), and joining each quest's nodes back reconstructs its
    `previous = [[A]][[B]]` line so the wikilinks can be read off it.
    """
    path = os.path.join(C.OFF, "officialwiki", "tasks.wiki")
    with open(path, encoding="utf-8") as fh:
        code = mwparserfromhell.parse(fh.read())

    sections, current, buf = {}, None, []
    for node in code.nodes:
        if isinstance(node, mwparserfromhell.nodes.Heading) and node.level == 1:
            if current is not None:
                sections[current] = "".join(buf)
            current, buf = str(node.title).strip(), []
        elif current is not None:
            buf.append(str(node))
    if current is not None:
        sections[current] = "".join(buf)

    previous = {}
    for name, section in sections.items():
        for line in section.splitlines():
            field = line.strip()
            if field.startswith("previous") and "=" in field:
                links = _wiki_previous_links(field.split("=", 1)[1])
                if links:
                    previous[name] = links
                break
    return previous


def merge_wiki_previous(rows):
    """Union the wiki's prerequisites into each task's `previous_tasks`.

    The graph is the union of `task_requirements` and `previous_tasks` (both
    point at prerequisites); the wiki only ever adds edges the API omitted.
    A cycle is impossible in the API graph, but the wiki can list two quests as
    each other's prerequisite, so an edge that would close a cycle is skipped
    (and counted). Edges the wiki joins with `or` are recorded in
    `alternative_previous_tasks` too: the player needs any one of them.
    Returns `(added, skipped)`, for the build report.
    """
    wiki = wiki_task_previous()
    by_name = { r["name"].casefold(): r["id"] for r in rows if r.get("name") }

    graph = {}
    for row in rows:
        reqs = { x["bsg_id"] for x in (row.get("task_requirements") or []) if x.get("bsg_id") }
        graph[row["id"]] = reqs | set(row.get("previous_tasks") or [])

    def reaches(start, target):
        """Does `start` reach `target` through prerequisite edges?"""
        seen, stack = set(), [ start ]
        while stack:
            for node in graph.get(stack.pop(), ()):
                if node == target:
                    return True
                if node not in seen:
                    seen.add(node)
                    stack.append(node)
        return False

    added = skipped = 0
    for row in rows:
        entries = wiki.get(row.get("name") or "")
        if not entries:
            continue
        for name, is_alternative in entries:
            prev_id = by_name.get(name.casefold())
            if not prev_id or prev_id == row["id"]:
                continue
            if prev_id in graph[row["id"]]:
                # Already a prerequisite (API or index); the wiki only adds the
                # `or` flag when it marks the group as alternatives.
                if is_alternative and prev_id not in row["alternative_previous_tasks"]:
                    row["alternative_previous_tasks"].append(prev_id)
                continue
            if reaches(prev_id, row["id"]):
                skipped += 1
                continue
            row["previous_tasks"].append(prev_id)
            graph[row["id"]].add(prev_id)
            if is_alternative:
                row["alternative_previous_tasks"].append(prev_id)
            added += 1
    return added, skipped


def annotate_task_graph(rows):
    """Add `graph` to every task row: prerequisite depth, in/out degree and
    membership of the Kappa / Lightkeeper prerequisite closures.

    The graph is the union of `task_requirements` and `previous_tasks`, both of
    which point at prerequisites. Verified acyclic in 99_verify.py.
    """
    ids = {r["id"] for r in rows}
    prereq = {r["id"]: {x["bsg_id"] for x in r["task_requirements"] if x.get("bsg_id") in ids}
              | {p for p in r["previous_tasks"] if p in ids} for r in rows}
    follow = {r["id"]: {x["task_id"] for x in r["leads_to"] if x["task_id"] in ids} for r in rows}

    depth = {}

    def d(tid, guard):
        if tid in depth:
            return depth[tid]
        if tid in guard:
            return 0                      # cycle guard; asserted acyclic elsewhere
        guard.add(tid)
        depth[tid] = 0 if not prereq[tid] else 1 + max(d(p, guard) for p in prereq[tid])
        guard.discard(tid)
        return depth[tid]

    for tid in ids:
        d(tid, set())

    def closure(seed):
        seen, stack = set(), list(seed)
        while stack:
            for v in prereq[stack.pop()]:
                if v not in seen:
                    seen.add(v)
                    stack.append(v)
        return seen

    kappa = {r["id"] for r in rows if r["kappa_required"]} | closure({r["id"] for r in rows if r["kappa_required"]})
    light = {r["id"] for r in rows if r["lightkeeper_required"]} | closure({r["id"] for r in rows if r["lightkeeper_required"]})

    for r in rows:
        tid = r["id"]
        r["graph"] = {
            "depth": depth[tid],
            "prerequisites": len(prereq[tid]),
            "dependents": len(follow[tid]),
            "kappa_chain": tid in kappa,
            "lightkeeper_chain": tid in light,
            "root": not prereq[tid],
        }
    return rows


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
            "start_rewards": reward_block(ctx, t.get("startRewards"), tid, "start"),
            "finish_rewards": reward_block(ctx, t.get("finishRewards"), tid, "finish"),
            "failure_outcome": reward_block(ctx, t.get("failureOutcome"), tid, "failure"),
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
            # Filled by merge_wiki_previous: the subset of previous_tasks the
            # wiki joined with `or` (any one of them suffices).
            "alternative_previous_tasks": [],
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


def _merge_unlocks(entries, key):
    """Dedupe unlock entries across sources; tarkovdev entries win."""
    out, seen = [], set()
    for e in entries:
        k = key(e)
        if k in seen:
            continue
        seen.add(k)
        out.append(e)
    return out


def reward_block(ctx, block, task_id=None, phase=None):
    """A task's reward block, with unlocks merged from both sources.

    `/regular/tasks` supplies offer/craft/trader unlocks but has no barter
    unlock at all; the derived index supplies barter unlocks and the
    trader/loyalty link for the others. Each entry is tagged `source`.
    """
    block = block or {}
    # The index records each unlock against the phase that grants it; keep only
    # this block's phase. tarkovdev has no barterUnlock at all, so barter gates
    # derived from `barter.taskUnlock` are attributed to the finish phase.
    _idx = index_unlocks(ctx).get(task_id, {"barter": [], "craft": [], "offer": []})
    idx = {k: [x for x in v if x.get("phase") == phase] for k, v in _idx.items()}
    items = [
        {**item_ref(ctx, i.get("item"), i.get("count")), "attributes": i.get("attributes") or {}}
        for i in (block.get("items") or [])
    ]
    return {
        "items": items,
        "barter_unlock": _merge_unlocks(
            ([
                {
                    "barter_id": b.get("id"), "trader_slug": (ctx["trader_by_id"].get(b.get("trader")) or {}).get("slug"),
                    "min_trader_level": b.get("minTraderLevel"), "buy_limit": b.get("buyLimit"),
                    "restock_amount": b.get("restockAmount"), "task_unlock_id": task_id,
                    "offered": {"bsg_id": (b.get("offeredItem") or {}).get("item"),
                                "name": ctx["names"].get((b.get("offeredItem") or {}).get("item")),
                                "count": (b.get("offeredItem") or {}).get("count")},
                    "required": [{"bsg_id": ri.get("item"), "name": ctx["names"].get(ri.get("item")), "count": ri.get("count")}
                                 for ri in (b.get("requiredItems") or [])],
                    "source": "tarkovdev", "phase": phase,
                }
                for b in ctx["barters"] if b.get("taskUnlock") == task_id
            ] if phase == "finish" else []) + idx["barter"],
            lambda x: ((x.get("offered") or {}).get("bsg_id"), x.get("trader_slug"), x.get("min_trader_level")),
        ),
        "trader_standing": [
            {
                "trader_id": s.get("trader"),
                "trader_slug": (ctx["trader_by_id"].get(s.get("trader")) or {}).get("slug"),
                "standing": s.get("standing"),
            }
            for s in (block.get("traderStanding") or [])
        ],
        "offer_unlock": _merge_unlocks(
            [
                {
                    **item_ref(ctx, o.get("item"), o.get("count")),
                    "unlock_id": o.get("id"),
                    "trader_id": o.get("trader"),
                    "trader_slug": (ctx["trader_by_id"].get(o.get("trader")) or {}).get("slug"),
                    "level": o.get("level"),
                    "source": "tarkovdev",
                }
                for o in (block.get("offerUnlock") or [])
            ] + idx["offer"],
            lambda x: (x.get("bsg_id"), x.get("trader_slug"), x.get("level")),
        ),
        "craft_unlock": _merge_unlocks(
            [
                {
                    **item_ref(ctx, c.get("item"), c.get("count")),
                    "station_id": c.get("station"),
                    "station_name": (station_names(ctx).get(c.get("station")) or {}).get("name"),
                    "level": c.get("level"),
                    "source": "tarkovdev",
                }
                for c in (block.get("craftUnlock") or [])
            ] + idx["craft"],
            lambda x: (x.get("bsg_id"), x.get("station_name"), x.get("level")),
        ),
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


def _ll(value):
    """'LL1' / '3' / '' -> int | None."""
    digits = re.sub(r"[^0-9]", "", str(value or ""))
    return int(digits) if digits else None


def _idx_item(blk):
    """Index entries keep counts as strings ("5"); normalize to int so merged
    barter/craft routes have one numeric shape."""
    count = blk.get("count")
    try:
        count = int(count) if count not in (None, "") else None
    except (TypeError, ValueError):
        count = None
    return {"bsg_id": blk.get("item_id"), "name": blk.get("item_name"), "count": count}


def barter_ref(ctx, b):
    """Normalize a tarkovdev barter into the canonical barter route shape."""
    off = (b.get("offeredItem") or {}).get("item")
    return {
        "barter_id": b.get("id"),
        "trader_slug": (ctx["trader_by_id"].get(b.get("trader")) or {}).get("slug"),
        "min_trader_level": b.get("minTraderLevel"),
        "buy_limit": b.get("buyLimit"),
        "restock_amount": b.get("restockAmount"),
        "task_unlock_id": b.get("taskUnlock"),
        "task_name": (ctx["task_by_id"].get(b.get("taskUnlock")) or {}).get("name"),
        "offered": {"bsg_id": off, "name": ctx["names"].get(off),
                    "count": (b.get("offeredItem") or {}).get("count")},
        "required": [
            {"bsg_id": ri.get("item"), "name": ctx["names"].get(ri.get("item")), "count": ri.get("count")}
            for ri in (b.get("requiredItems") or [])
        ],
        "source": "tarkovdev",
    }


def craft_ref(ctx, c):
    """Normalize a tarkovdev craft into the canonical craft route shape."""
    prod = c.get("productItem") or {}
    return {
        "craft_id": c.get("id"),
        "station_id": c.get("station"),
        "station_name": (station_names(ctx).get(c.get("station")) or {}).get("name"),
        "level": c.get("level"),
        "duration": c.get("duration"),
        "task_unlock_id": c.get("taskUnlock"),
        "task_name": (ctx["task_by_id"].get(c.get("taskUnlock")) or {}).get("name"),
        "product": {"bsg_id": prod.get("item"), "name": ctx["names"].get(prod.get("item")), "count": prod.get("count")},
        "required": [
            {"bsg_id": ri.get("item"), "name": ctx["names"].get(ri.get("item")),
             "count": ri.get("count"), "is_tool": bool((ri.get("attributes") or {}).get("tool"))}
            for ri in (c.get("requiredItems") or [])
        ],
        "source": "tarkovdev",
    }


def index_unlocks(ctx):
    """Unlocks the derived unlockables index carries that `/regular/tasks` does not.

    The JSON API exposes no `barterUnlock` reward at all, so task-gated barters
    exist *only* here — 45 items, 13 of which appear in no tarkovdev barter.
    Craft and offer unlock links are included too, as cross-checks, tagged
    `source: tarkovunlockables`. Cached on ctx.
    """
    if "_index_unlocks" in ctx:
        return ctx["_index_unlocks"]
    out = {}
    for t in ctx["tasks_index"]:
        tid = t.get("bsg_id")
        if not tid:
            continue
        entry = {"barter": [], "craft": [], "offer": []}
        for phase, key in (("start", "start_rewards"), ("finish", "finish_rewards")):
            for r in (t.get(key) or []):
                for bu in (r.get("barter_unlocks") or []):
                    offered, required, slug, lvl = None, [], None, None
                    for res in (bu.get("result") or []):
                        for it in (res.get("items") or []):
                            offered = offered or _idx_item(it)
                    for req in (bu.get("requirements") or []):
                        if slug is None:
                            slug = (req.get("trader_name") or "").strip().lower().replace("_", "-") or None
                            lvl = _ll(req.get("trader_level"))
                        required += [_idx_item(i) for i in (req.get("items") or [])]
                    entry["barter"].append({
                        "barter_id": None, "trader_slug": slug, "min_trader_level": lvl,
                        "buy_limit": None, "restock_amount": None, "task_unlock_id": tid,
                        "task_name": ctx["task_by_id"].get(tid, {}).get("name"),
                        "offered": offered, "required": required,
                        "source": "tarkovunlockables", "phase": phase,
                    })
                for cu in (r.get("craft_unlocks") or []):
                    entry["craft"].append({
                        "bsg_id": cu.get("item_id"), "name": cu.get("item_name"),
                        "station_name": cu.get("hideout_station"), "level": _ll(cu.get("station_level")),
                        "source": "tarkovunlockables", "phase": phase,
                    })
                for ou in (r.get("offer_unlocks") or []):
                    entry["offer"].append({
                        "bsg_id": ou.get("item_id"), "name": ou.get("item_name"),
                        "trader_slug": (ou.get("trader_name") or "").strip().lower().replace("_", "-") or None,
                        "level": _ll(ou.get("trader_level")),
                        "source": "tarkovunlockables", "phase": phase,
                    })
        if entry["barter"] or entry["craft"] or entry["offer"]:
            out[tid] = entry
    ctx["_index_unlocks"] = out
    return out


def index_barter_routes(ctx):
    """All index barter-unlock recipes, flattened, with a dedupe key."""
    routes = []
    for tid, blk in index_unlocks(ctx).items():
        for be in blk["barter"]:
            routes.append(be)
    return routes


def build_items(ctx):
    raw_items = ctx["raw"]["items"]
    quest_items = ctx["quest_items"]
    index = ctx["index_by_id"]
    wiki = ctx["wiki_items"]
    en = ctx["en_items"]
    cats = ctx["raw"]["item_categories"]
    hcats = ctx["raw"]["handbook_categories"]

    # --- forward/reverse acquisition prepasses ---------------------------
    # Entries are stored already normalized so tarkovdev and the derived index
    # can be merged into one list without the consumer caring where each came from.
    barter_by_offered = defaultdict(list)
    barter_uses = defaultdict(list)
    seen_barter = defaultdict(set)          # offered_id -> dedupe keys already present
    for b in ctx["barters"]:
        ref = barter_ref(ctx, b)
        off = ref["offered"]["bsg_id"]
        if off:
            barter_by_offered[off].append(ref)
        for ri in ref["required"]:
            if ri.get("bsg_id"):
                barter_uses[ri["bsg_id"]].append(ref)
    for ref in index_barter_routes(ctx):
        off = (ref["offered"] or {}).get("bsg_id")
        if not off:
            continue
        key = (ref["trader_slug"], ref["min_trader_level"], ref["task_unlock_id"])
        if key in seen_barter[off]:
            continue
        seen_barter[off].add(key)
        barter_by_offered[off].append(ref)
        for ri in ref["required"]:
            if ri.get("bsg_id"):
                barter_uses[ri["bsg_id"]].append(ref)

    craft_by_product = defaultdict(list)
    craft_uses = defaultdict(list)
    for c in ctx["crafts"]:
        ref = craft_ref(ctx, c)
        prod = ref["product"]["bsg_id"]
        if prod:
            craft_by_product[prod].append(ref)
        for ri in ref["required"]:
            if ri.get("bsg_id"):
                craft_uses[ri["bsg_id"]].append(ref)

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


WIKI_PSEUDO_SLOTS = frozenset({"Compatibility", "Conflicting items"})
WIKI_TRADER_RE = re.compile(r"\[\[([^\]|#]+)(?:#[^\]|]*)?(?:\|[^\]]*)?\]\]\s*(LL\d)?")
WIKI_FACTION_RE = re.compile(r"^\s*\[\[([^\]|#]+)(?:#[^\]|]*)?(?:\|[^\]]*)?\]\]\s*:\s*(.+)$")
WIKI_FACTIONS = frozenset({"bear", "usec"})


def parse_wiki_trader(text):
    """Parse the wiki infobox `trader` field into structured offers.

    Shape: `[[Peacekeeper]] LL3: Standard<br/>[[Mechanic]] LL3<br/>...` where
    the part after ':' names the weapon variant the trader sells. This is an
    independent, human-maintained view of the buy routes.
    """
    if not text:
        return []
    out = []
    for chunk in str(text).split("<br/>"):
        faction = None
        fm = WIKI_FACTION_RE.match(chunk)
        if fm and C.slugify(fm.group(1)) in WIKI_FACTIONS:
            faction = C.slugify(fm.group(1))
            chunk = fm.group(2)
        m = WIKI_TRADER_RE.search(chunk)
        if not m:
            continue
        page = m.group(1).strip()
        level = m.group(2)
        variant = chunk.split(":", 1)[1].strip() if ":" in chunk.split("]]", 1)[-1] else None
        if variant:
            variant = re.sub(r"\[\[([^\]|]+)(?:\|[^\]]*)?\]\]", r"\1", variant).strip() or None
        out.append({
            "trader_name": page,
            "trader_slug": C.slugify(page) or page.lower().replace(" ", "-"),
            "level": level,
            "level_number": _ll(level),
            "variant": variant,
            "faction": faction,
        })
    return out


def wiki_section(wiki_item, label):
    """Item ids from one of the wiki parser's pseudo-sections."""
    if not wiki_item:
        return []
    for m in (wiki_item.get("sections") or {}).get("mods") or []:
        if m.get("slot") == label:
            return [x for x in (m.get("items") or []) if x]
    return []


def _item_row(ctx, i, it, props, pt, idx, w, mk, ob, cats, hcats, en, station,
              barter_by_offered, barter_uses, craft_by_product, craft_uses,
              reward_items, objective_uses, hideout_uses, sources):
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
            # The API supplies 11,312 conflict relations over 574 items; the
            # wiki corroborates 2,054 of them and adds 192 more for 242 items.
            # Kept under `wiki_items` so the API fields stay verbatim.
            "items": it.get("conflictingItems") or [],
            "slot_ids": it.get("conflictingSlotIds") or [],
            "categories": it.get("conflictingCategories") or [],
            "wiki_items": [item_ref(ctx, c) for c in wiki_section(w, "Conflicting items")],
        },
        "compatibility": [item_ref(ctx, c) for c in wiki_section(w, "Compatibility")],
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
            "internal_id": (w.get("infobox") or {}).get("ID"),
            "xp": {k: (w.get("infobox") or {}).get(k) for k in ("loot_xp", "exam_xp")
                   if (w.get("infobox") or {}).get(k) is not None},
            "price": (w.get("infobox") or {}).get("price"),
            "trader_offers": parse_wiki_trader((w.get("infobox") or {}).get("trader")),
            "infobox": w.get("infobox") or {},
            "mod_slots": [
                {"slot": m.get("slot"), "items": [item_ref(ctx, x) for x in (m.get("items") or [])]}
                for m in ((w.get("sections") or {}).get("mods") or [])
                if (m.get("slot") or "") not in WIKI_PSEUDO_SLOTS
            ],
            "weapon_variants": (w.get("sections") or {}).get("weapon_variants") or [],
        } if w else None),
        "market": ({"uid": mk.get("uid"), "tags": mk.get("tags") or [], "name": mk.get("name"), "short_name": mk.get("shortName")} if mk else None),
        "acquisition": {
            "buy": buy_routes(ctx, it),
            "index_offers": index_offers(ctx, ob),
            "barter": barter_by_offered.get(i, []),
            "craft": craft_by_product.get(i, []),
            "task_rewards": reward_items.get(i, []),
        },
        "used_in": {
            "crafts": craft_uses.get(i, []),
            "barters": barter_uses.get(i, []),
            "hideout_build": hideout_uses.get(i, []),
            "task_objectives": objective_uses.get(i, []),
        },
        "sources": sources,
    }


# --------------------------------------------------------------------------- #
# reference + report
# --------------------------------------------------------------------------- #
def build_weapon_variants(ctx):
    """The wiki's named weapon builds.

    Items with a `weapon_variants` wiki section are keyed by the base weapon's
    bsg id; each variant names a build and lists its attachment ids. These are
    community-named builds on top of tarkovdev's 484 presets, so each variant is
    matched back to the preset it names (they are usually the same build).
    """
    def norm(text):
        return re.sub(r"[^a-z0-9]+", "", (text or "").lower())

    def descriptor(base_name, variant_name):
        """The part of a variant name that is not the base weapon's own words,
        e.g. ('AS VAL 9x39 special assault rifle', 'AS VAL Kobra') -> 'kobra'."""
        base_words = set(re.findall(r"[a-z0-9]+", (base_name or "").lower()))
        rest = [w for w in re.findall(r"[a-z0-9]+", (variant_name or "").lower())
                if w not in base_words]
        return "".join(rest)

    presets_by_base = defaultdict(list)
    for bsg_id, raw in ctx["raw"]["items"].items():
        props = raw.get("properties") or {}
        if props.get("propertiesType") == "ItemPropertiesPreset" and props.get("baseItem"):
            presets_by_base[props["baseItem"]].append((bsg_id, raw.get("normalizedName") or ""))

    rows = []
    for bsg_id, parsed in ctx["wiki_items"].items():
        variants = ((parsed.get("sections") or {}).get("weapon_variants") or [])
        base_name = ctx["names"].get(bsg_id)
        for v in variants:
            name = v.get("name")
            # The wiki abbreviates base names ("M700 ARCH" for "Remington
            # Model 700 ... ARCH"), so try the full descriptor first and then
            # progressively shorter trailing token groups. Matching is already
            # restricted to presets of the same base weapon.
            words = [w for w in re.findall(r"[a-z0-9]+", (name or "").lower())
                     if w not in set(re.findall(r"[a-z0-9]+", (base_name or "").lower()))]
            needles = []
            full = descriptor(base_name, name) or norm(name)
            if full:
                needles.append(full)
            for n in (3, 2, 1):
                if len(words) >= n:
                    tok = "".join(words[-n:])
                    if tok not in needles:
                        needles.append(tok)
            # Suffix match only: a substring test would make "SOPMOD I" match
            # "sopmod-ii" (both contain "sopmodi").
            preset = None
            for needle in needles:
                for pid, slug in presets_by_base.get(bsg_id, []):
                    if norm(slug).endswith(needle):
                        preset = (pid, slug)
                        break
                if preset:
                    break
            attachments = []
            for a in v.get("attachments") or []:
                if a:
                    attachments.append({"bsg_id": a, "name": ctx["names"].get(a)})
            rows.append({
                "base_bsg_id": bsg_id,
                "base_name": base_name,
                "name": name,
                "attachments": attachments,
                "preset_bsg_id": preset[0] if preset else None,
                "preset_slug": preset[1] if preset else None,
            })
    return rows


def resolve_special_items(ctx):
    """`specialItems` is a mixed id list, not an item list.

    It holds 28 item ids plus the **category** ids of the special-slot item
    groups (compass, portable range finder, radio transmitter, map, multitools,
    planting kits, recorder, cultist amulet, mark of the unheard). Joining the
    raw list to `items` silently drops those 9 rows, so each entry is resolved
    to its kind and display name here.

    `types` containing `specialSlot` is the authoritative signal for "can go in
    the special slot" (44 items); every category member is already typed that
    way, so this resolution is for explanation, not for completeness.
    """
    items = {i["bsg_id"]: i for i in ctx.get("items") or []}
    cats = {c["id"]: c["slug"] for c in build_categories(ctx)}
    out = []
    for sid in ctx["raw"]["special_items"] or []:
        if sid in items:
            out.append({"id": sid, "kind": "item", "name": items[sid]["name"]})
        elif sid in cats:
            out.append({"id": sid, "kind": "category", "name": C.humanize(cats[sid])})
        else:
            out.append({"id": sid, "kind": "unknown", "name": None})
    return out


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
        "special_items": resolve_special_items(ctx),
        "settings": ctx["raw"]["settings"],
        "wiki_expansion": dict(EXPANSION),
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
    wiki_edges, wiki_cycles = merge_wiki_previous(tasks)
    tasks = annotate_task_graph(tasks)
    stats["tasks"] = C.write_jsonl(os.path.join(C.CANON, "tasks.ndjson"), tasks)
    stats["maps"] = C.write_jsonl(os.path.join(C.CANON, "maps.ndjson"), build_maps(ctx))
    stats["hideout_stations"] = C.write_jsonl(os.path.join(C.CANON, "hideout_stations.ndjson"), build_hideout(ctx))
    ctx["items"] = list(build_items(ctx))
    stats["items"] = C.write_jsonl(os.path.join(C.CANON, "items.ndjson"), ctx["items"])
    stats["weapon_variants"] = C.write_jsonl(os.path.join(C.CANON, "weapon_variants.ndjson"), build_weapon_variants(ctx))

    with open(os.path.join(C.CANON, "reference.json"), "w", encoding="utf-8") as fh:
        json.dump(build_reference(ctx), fh, ensure_ascii=False, indent=1)

    name_src = Counter(ctx["name_src"].values())
    lines = ["# Canonical build", "", "| entity | rows |", "| --- | ---: |"]
    lines += [f"| {k} | {v} |" for k, v in stats.items()]
    lines += ["", "## Task graph", "", f"- wiki prerequisite edges merged: {wiki_edges}",
              f"- wiki edges skipped to keep the graph acyclic: {wiki_cycles}"]
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
