#!/usr/bin/env python3
"""Load the canonical dataset into a single indexed SQLite database.

`canonical/` is the durable, diffable form; `tarkov.sqlite3` is the queryable
one. Tables mirror the canonical entities plus the join tables the NDJSON
nests (slots, trade, acquisition, rewards, hideout requirements). An FTS5
index on item names powers search.

Run: ~/.pyvenv-tarkov/bin/python datastore/scripts/30_build_sqlite.py
"""
from __future__ import annotations

import json
import os
import sqlite3

import _common as C

SCHEMA = """
PRAGMA journal_mode = WAL;

CREATE TABLE items (
  bsg_id TEXT PRIMARY KEY,
  slug TEXT,
  name TEXT,
  short_name TEXT,
  description TEXT,
  name_source TEXT,
  quest_item INTEGER DEFAULT 0,
  properties_type TEXT,
  width INTEGER, height INTEGER, weight REAL,
  stack_max_size INTEGER, has_grid INTEGER, discard_limit INTEGER, background_color TEXT,
  base_price INTEGER, last_low_price INTEGER, avg24h_price INTEGER, low24h_price INTEGER,
  high24h_price INTEGER, change_last_48h REAL, change_last_48h_percent REAL,
  last_offer_count INTEGER, min_level_for_flea INTEGER, last_scan TEXT,
  armor_class INTEGER, damage INTEGER, penetration_power INTEGER,
  caliber TEXT, ergonomics REAL, max_durability REAL, uses INTEGER,
  tarkovdev_url TEXT, wiki_url TEXT, market_url TEXT, market_tags TEXT,
  image_icon TEXT, image_grid TEXT, image_market TEXT,
  properties TEXT, stats TEXT, conflicts TEXT, wiki_infobox TEXT, market TEXT, sources TEXT
);

CREATE TABLE item_types (bsg_id TEXT, type TEXT, PRIMARY KEY (bsg_id, type));
CREATE TABLE item_categories (bsg_id TEXT, kind TEXT, category_id TEXT, path TEXT);
CREATE TABLE item_sources (bsg_id TEXT, source TEXT, PRIMARY KEY (bsg_id, source));
CREATE TABLE item_contained (bsg_id TEXT, contained_bsg_id TEXT, count INTEGER);
CREATE TABLE item_grids (bsg_id TEXT, width INTEGER, height INTEGER, allowed_categories TEXT, allowed_items TEXT);
CREATE TABLE item_conflicts (bsg_id TEXT, other_bsg_id TEXT, source TEXT);
CREATE TABLE item_compatibility (bsg_id TEXT, other_bsg_id TEXT);
CREATE TABLE item_wiki_slots (bsg_id TEXT, slot TEXT, allowed_bsg_id TEXT);
CREATE TABLE item_wiki_meta (bsg_id TEXT PRIMARY KEY, internal_id TEXT, price INTEGER, loot_xp INTEGER, exam_xp INTEGER);
CREATE TABLE item_wiki_trader_offers (
  bsg_id TEXT, trader_slug TEXT, trader_name TEXT, level INTEGER, variant TEXT, faction TEXT
);

CREATE TABLE item_slots (
  id TEXT PRIMARY KEY, bsg_id TEXT, name_id TEXT, name TEXT, required INTEGER, allowed_count INTEGER
);
CREATE TABLE item_slot_allowed (slot_id TEXT, allowed_bsg_id TEXT);

CREATE TABLE item_trade (
  bsg_id TEXT, direction TEXT, trader_slug TEXT,
  price INTEGER, price_rub INTEGER, currency TEXT, min_trader_level INTEGER,
  task_unlock_id TEXT, buy_limit INTEGER
);

CREATE TABLE item_acquisition (
  bsg_id TEXT, route TEXT, ref_id TEXT, trader_slug TEXT, station TEXT,
  level INTEGER, count INTEGER, detail TEXT
);
CREATE TABLE item_used_in (
  bsg_id TEXT, route TEXT, ref_id TEXT, label TEXT, count INTEGER, detail TEXT
);

CREATE TABLE categories (
  id TEXT PRIMARY KEY, kind TEXT, slug TEXT, parent_id TEXT, path TEXT, depth INTEGER,
  min_level_for_flea INTEGER, image_url TEXT
);

CREATE TABLE traders (
  id TEXT PRIMARY KEY, slug TEXT, name TEXT, description TEXT, currency TEXT,
  reset_time TEXT, discount INTEGER, image_url TEXT, task_count INTEGER
);
CREATE TABLE trader_levels (
  trader_id TEXT, level INTEGER, required_player_level INTEGER, required_reputation REAL,
  required_commerce REAL, pay_rate REAL, insurance_rate REAL, repair_cost_multiplier REAL
);
CREATE TABLE trader_buy_rules (trader_id TEXT, direction TEXT, kind TEXT, value TEXT);

CREATE TABLE barters (
  id TEXT PRIMARY KEY, trader_slug TEXT, min_trader_level INTEGER, buy_limit INTEGER,
  restock_amount INTEGER, task_unlock_id TEXT, offered_bsg_id TEXT, offered_count INTEGER
);
CREATE TABLE barter_required (barter_id TEXT, bsg_id TEXT, count INTEGER, is_tool INTEGER);

CREATE TABLE crafts (
  id TEXT PRIMARY KEY, station_id TEXT, station_slug TEXT, station_name TEXT, level INTEGER,
  duration INTEGER, task_unlock_id TEXT, product_bsg_id TEXT, product_count INTEGER, game_editions TEXT
);
CREATE TABLE craft_required (craft_id TEXT, bsg_id TEXT, count INTEGER, is_tool INTEGER, is_quest INTEGER);

CREATE TABLE tasks (
  id TEXT PRIMARY KEY, slug TEXT, name TEXT, name_source TEXT, wiki_link TEXT,
  trader_slug TEXT, trader_name TEXT, map_id TEXT, map_name TEXT,
  min_player_level INTEGER, experience INTEGER, faction TEXT,
  kappa_required INTEGER, lightkeeper_required INTEGER, restartable INTEGER,
  required_prestige TEXT, game_mode TEXT, objective_count INTEGER, task_image_url TEXT
);
CREATE TABLE task_graph (
  task_id TEXT PRIMARY KEY, depth INTEGER, prerequisites INTEGER, dependents INTEGER,
  kappa_chain INTEGER, lightkeeper_chain INTEGER, root INTEGER
);
CREATE TABLE task_objectives (
  id TEXT, task_id TEXT, type TEXT, description TEXT, optional INTEGER, count INTEGER,
  PRIMARY KEY (task_id, id)
);
CREATE TABLE task_objective_items (objective_id TEXT, bsg_id TEXT, name TEXT);
CREATE TABLE task_objective_refs (objective_id TEXT, ref_id TEXT, name TEXT);
CREATE TABLE task_task_requirements (task_id TEXT, required_task_id TEXT, required_task_name TEXT);
CREATE TABLE task_trader_requirements (
  task_id TEXT, trader_slug TEXT, requirement_type TEXT, compare_method TEXT, value TEXT
);
CREATE TABLE task_leads_to (task_id TEXT, follow_up_task_id TEXT, follow_up_task_name TEXT);
CREATE TABLE task_previous_tasks (task_id TEXT, previous_task_id TEXT);
CREATE TABLE task_needed_keys (task_id TEXT, map_id TEXT, key_bsg_id TEXT);
CREATE TABLE task_rewards (
  task_id TEXT, phase TEXT, kind TEXT, bsg_id TEXT, name TEXT, count INTEGER,
  trader_slug TEXT, station TEXT, level INTEGER, extra TEXT
);

CREATE TABLE hideout_stations (
  id TEXT PRIMARY KEY, slug TEXT, name TEXT, area_type INTEGER, image_url TEXT
);
CREATE TABLE hideout_levels (station_id TEXT, level INTEGER, construction_time INTEGER);
CREATE TABLE hideout_level_items (
  station_id TEXT, level INTEGER, bsg_id TEXT, count INTEGER, found_in_raid INTEGER
);
CREATE TABLE hideout_level_station_reqs (station_id TEXT, level INTEGER, req_station_id TEXT, req_level INTEGER);
CREATE TABLE hideout_level_trader_reqs (station_id TEXT, level INTEGER, trader_slug TEXT, req_level INTEGER);

CREATE TABLE weapon_variants (
  base_bsg_id TEXT, name TEXT, preset_bsg_id TEXT, preset_slug TEXT, attachment_count INTEGER,
  PRIMARY KEY (base_bsg_id, name)
);
CREATE TABLE weapon_variant_attachments (
  base_bsg_id TEXT, variant_name TEXT, bsg_id TEXT
);

CREATE TABLE maps (
  id TEXT PRIMARY KEY, slug TEXT, name TEXT, name_id TEXT, wiki_link TEXT,
  raid_duration INTEGER, players TEXT, enemies TEXT, bosses TEXT, extracts TEXT, transits TEXT
);

CREATE TABLE player_levels (level INTEGER PRIMARY KEY, exp INTEGER, badge_image TEXT);
CREATE TABLE skills (id TEXT PRIMARY KEY, name TEXT, slug TEXT, wiki_link TEXT, image_url TEXT);
CREATE TABLE armor_materials (
  id TEXT PRIMARY KEY, name TEXT, destructibility REAL, explosion_destructibility REAL,
  max_repair_degradation REAL, max_repair_kit_degradation REAL,
  min_repair_degradation REAL, min_repair_kit_degradation REAL
);
CREATE TABLE mastery (id TEXT PRIMARY KEY, weapons TEXT);
CREATE TABLE achievements (
  id TEXT PRIMARY KEY, name TEXT, slug TEXT, description TEXT, hidden INTEGER,
  side TEXT, rarity TEXT, players_completed_percent REAL
);
CREATE TABLE settings (key TEXT PRIMARY KEY, json TEXT);

CREATE VIRTUAL TABLE items_fts USING fts5(
  bsg_id UNINDEXED, name, short_name, slug, tokenize = "unicode61 remove_diacritics 2"
);

CREATE INDEX idx_items_name ON items(name);
CREATE INDEX idx_items_slug ON items(slug);
CREATE INDEX idx_items_ptype ON items(properties_type);
CREATE INDEX idx_items_caliber ON items(caliber);
CREATE INDEX idx_item_types_type ON item_types(type);
CREATE INDEX idx_item_grids ON item_grids(bsg_id);
CREATE INDEX idx_item_conflicts ON item_conflicts(bsg_id);
CREATE INDEX idx_item_conflict_other ON item_conflicts(other_bsg_id);
CREATE INDEX idx_item_compat ON item_compatibility(bsg_id);
CREATE INDEX idx_item_compat_other ON item_compatibility(other_bsg_id);
CREATE INDEX idx_item_wiki_slots ON item_wiki_slots(bsg_id);
CREATE INDEX idx_item_wiki_offers ON item_wiki_trader_offers(bsg_id);
CREATE INDEX idx_item_wiki_offers_trader ON item_wiki_trader_offers(trader_slug);
CREATE INDEX idx_item_cat ON item_categories(kind, category_id);
CREATE INDEX idx_item_slot ON item_slots(bsg_id);
CREATE INDEX idx_slot_allowed ON item_slot_allowed(allowed_bsg_id);
CREATE INDEX idx_trade_item ON item_trade(bsg_id, direction);
CREATE INDEX idx_trade_trader ON item_trade(trader_slug);
CREATE INDEX idx_acq_item ON item_acquisition(bsg_id, route);
CREATE INDEX idx_used_item ON item_used_in(bsg_id, route);
CREATE INDEX idx_barter_offered ON barters(offered_bsg_id);
CREATE INDEX idx_barter_trader ON barters(trader_slug);
CREATE INDEX idx_barter_req ON barter_required(bsg_id);
CREATE INDEX idx_craft_product ON crafts(product_bsg_id);
CREATE INDEX idx_craft_station ON crafts(station_slug);
CREATE INDEX idx_craft_req ON craft_required(bsg_id);
CREATE INDEX idx_task_trader ON tasks(trader_slug);
CREATE INDEX idx_task_map ON tasks(map_id);
CREATE INDEX idx_task_obj ON task_objectives(task_id);
CREATE INDEX idx_task_graph ON task_graph(depth);
CREATE INDEX idx_wv_base ON weapon_variants(base_bsg_id);
CREATE INDEX idx_wv_preset ON weapon_variants(preset_bsg_id);
CREATE INDEX idx_wva_variant ON weapon_variant_attachments(base_bsg_id, variant_name);
CREATE INDEX idx_obj_items ON task_objective_items(bsg_id);
CREATE INDEX idx_rewards_item ON task_rewards(bsg_id);
CREATE INDEX idx_rewards_task ON task_rewards(task_id, phase);
CREATE INDEX idx_hideout_item ON hideout_level_items(bsg_id);
"""

VIEWS = """
CREATE VIEW v_item_price AS
SELECT i.bsg_id, i.name, i.slug, i.avg24h_price, i.base_price, i.min_level_for_flea,
       (SELECT MAX(price_rub) FROM item_trade t WHERE t.bsg_id = i.bsg_id AND t.direction = 'sell_to') AS best_trader_sell,
       (SELECT MIN(price_rub) FROM item_trade t WHERE t.bsg_id = i.bsg_id AND t.direction = 'buy_from') AS best_trader_buy
FROM items i;

CREATE VIEW v_item_acquisition AS
SELECT a.bsg_id, i.name, a.route, a.ref_id, a.trader_slug, a.station, a.level, a.count
FROM item_acquisition a JOIN items i ON i.bsg_id = a.bsg_id;

CREATE VIEW v_weapon_variant_attachments AS
SELECT a.base_bsg_id, v.name AS variant_name, a.bsg_id, i.name AS attachment_name
FROM weapon_variant_attachments a
JOIN weapon_variants v ON v.base_bsg_id = a.base_bsg_id AND v.name = a.variant_name
LEFT JOIN items i ON i.bsg_id = a.bsg_id;

CREATE VIEW v_item_armor AS
SELECT i.bsg_id, i.name,
       json_extract(i.properties, '$.class') AS armor_class,
       json_extract(i.properties, '$.material') AS material_id,
       am.name AS material_name, am.destructibility, am.max_repair_degradation,
       am.min_repair_degradation,
       json_extract(i.properties, '$.durability') AS durability,
       json_extract(i.properties, '$.bluntThroughput') AS blunt_throughput,
       json_extract(i.properties, '$.zones') AS zones
FROM items i
LEFT JOIN armor_materials am ON am.id = json_extract(i.properties, '$.material')
WHERE json_extract(i.properties, '$.material') IS NOT NULL;

CREATE VIEW v_task_chain AS
SELECT l.task_id, t.name AS task_name, l.follow_up_task_id, l.follow_up_task_name
FROM task_leads_to l JOIN tasks t ON t.id = l.task_id;
"""


def connect():
    if os.path.exists(C.SQLITE):
        os.remove(C.SQLITE)
    for suffix in ("-wal", "-shm"):
        if os.path.exists(C.SQLITE + suffix):
            os.remove(C.SQLITE + suffix)
    con = sqlite3.connect(C.SQLITE)
    con.executescript(SCHEMA)
    return con


def main():
    con = connect()
    cur = con.cursor()
    stats = {}

    # ---- categories ------------------------------------------------------
    rows = list(C.load_jsonl(os.path.join(C.CANON, "categories.ndjson")))
    cur.executemany("INSERT INTO categories VALUES (?,?,?,?,?,?,?,?)",
                    [(r["id"], r["kind"], r["slug"], r["parent_id"], r["path"], r["depth"],
                      r["min_level_for_flea"], r["image_url"]) for r in rows])
    stats["categories"] = len(rows)

    # ---- traders ---------------------------------------------------------
    rows = list(C.load_jsonl(os.path.join(C.CANON, "traders.ndjson")))
    cur.executemany("INSERT INTO traders VALUES (?,?,?,?,?,?,?,?,?)",
                    [(r["id"], r["slug"], r["name"], r["description"], r["currency"],
                      r["reset_time"], r["discount"], r["image_url"], r["task_count"]) for r in rows])
    for r in rows:
        cur.executemany("INSERT INTO trader_levels VALUES (?,?,?,?,?,?,?,?)",
                        [(r["id"], lv["level"], lv["required_player_level"], lv["required_reputation"],
                          lv["required_commerce"], lv["pay_rate"], lv["insurance_rate"],
                          lv["repair_cost_multiplier"]) for lv in r["levels"]])
        for direction, blk in (("allowed", r["buy_allowed"]), ("prohibited", r["buy_prohibited"])):
            cur.executemany("INSERT INTO trader_buy_rules VALUES (?,?,?,?)",
                            [(r["id"], direction, "category", c) for c in blk["categories"]]
                            + [(r["id"], direction, "item", i) for i in blk["items"]])
    stats["traders"] = len(rows)

    # ---- barters ---------------------------------------------------------
    rows = list(C.load_jsonl(os.path.join(C.CANON, "barters.ndjson")))
    cur.executemany("INSERT OR REPLACE INTO barters VALUES (?,?,?,?,?,?,?,?)",
                    [(r["id"], r["trader_slug"], r["min_trader_level"], r["buy_limit"],
                      r["restock_amount"], r["task_unlock_id"],
                      (r["offered_item"] or {}).get("bsg_id"), (r["offered_item"] or {}).get("count")) for r in rows])
    for r in rows:
        cur.executemany("INSERT INTO barter_required VALUES (?,?,?,?)",
                        [(r["id"], ri["bsg_id"], ri.get("count"), 0)
                         for ri in r["required_items"] if ri.get("bsg_id")])
    stats["barters"] = len(rows)

    # ---- crafts ----------------------------------------------------------
    rows = list(C.load_jsonl(os.path.join(C.CANON, "crafts.ndjson")))
    cur.executemany("INSERT OR REPLACE INTO crafts VALUES (?,?,?,?,?,?,?,?,?,?)",
                    [(r["id"], r["station_id"], r["station_slug"], r["station_name"], r["level"],
                      r["duration"], r["task_unlock_id"], (r["product_item"] or {}).get("bsg_id"),
                      (r["product_item"] or {}).get("count"), json.dumps(r["game_editions"])) for r in rows])
    for r in rows:
        cur.executemany("INSERT INTO craft_required VALUES (?,?,?,?,?)",
                        [(r["id"], ri["bsg_id"], ri.get("count"), int(bool(ri.get("is_tool"))), 0)
                         for ri in r["required_items"] if ri.get("bsg_id")]
                        + [(r["id"], qi["bsg_id"], qi.get("count"), 0, 1)
                           for qi in r["required_quest_items"] if qi.get("bsg_id")])
    stats["crafts"] = len(rows)

    # ---- tasks -----------------------------------------------------------
    rows = list(C.load_jsonl(os.path.join(C.CANON, "tasks.ndjson")))
    cur.executemany("INSERT OR REPLACE INTO tasks VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                    [(r["id"], r["slug"], r["name"], r["name_source"], r["wiki_link"],
                      r["trader_slug"], r["trader_name"], r["map_id"], r["map_name"],
                      r["min_player_level"], r["experience"], r["faction"],
                      int(bool(r["kappa_required"])), int(bool(r["lightkeeper_required"])),
                      int(bool(r["restartable"])), r["required_prestige"],
                      json.dumps(r["game_mode"]), len(r["objectives"]), r["task_image_url"]) for r in rows])
    for r in rows:
        tid = r["id"]
        g = r.get("graph") or {}
        cur.execute("INSERT OR REPLACE INTO task_graph VALUES (?,?,?,?,?,?,?)",
                    (tid, g.get("depth"), g.get("prerequisites"), g.get("dependents"),
                     int(bool(g.get("kappa_chain"))), int(bool(g.get("lightkeeper_chain"))), int(bool(g.get("root")))))
        for o in r["objectives"]:
            cur.execute("INSERT OR REPLACE INTO task_objectives VALUES (?,?,?,?,?,?)",
                        (o["id"], tid, o["type"], o["description"], int(bool(o["optional"])), o["count"]))
            items = (o["raw"].get("items") or []) if isinstance(o["raw"], dict) else []
            for i in items:
                nm = o["id_names"].get(i)
                cur.execute("INSERT INTO task_objective_items VALUES (?,?,?)", (o["id"], i, nm))
            if o.get("id_names"):
                cur.executemany("INSERT INTO task_objective_refs VALUES (?,?,?)",
                                [(o["id"], k, v) for k, v in o["id_names"].items()])
        for tr in r["task_requirements"]:
            cur.execute("INSERT INTO task_task_requirements VALUES (?,?,?)",
                        (tid, tr.get("bsg_id"), tr.get("name")))
        cur.executemany("INSERT INTO task_trader_requirements VALUES (?,?,?,?,?)",
                        [(tid, x["trader_slug"], x["requirement_type"], x["compare_method"], str(x["value"]))
                         for x in r["trader_requirements"]])
        cur.executemany("INSERT INTO task_leads_to VALUES (?,?,?)",
                        [(tid, x["task_id"], x["task_name"]) for x in r["leads_to"]])
        cur.executemany("INSERT INTO task_previous_tasks VALUES (?,?)",
                        [(tid, p) for p in r["previous_tasks"]])
        for nk in r["needed_keys"]:
            for k in nk["keys"]:
                cur.execute("INSERT INTO task_needed_keys VALUES (?,?,?)", (tid, nk["map_id"], k.get("bsg_id")))
        for phase in ("start_rewards", "finish_rewards", "failure_outcome"):
            for i in r[phase]["items"]:
                cur.execute("INSERT INTO task_rewards VALUES (?,?,?,?,?,?,?,?,?,?)",
                            (tid, phase, "item", i.get("bsg_id"), i.get("name"), i.get("count"),
                             None, None, None, json.dumps(i.get("attributes") or {})))
            for ts in r[phase]["trader_standing"]:
                cur.execute("INSERT INTO task_rewards VALUES (?,?,?,?,?,?,?,?,?,?)",
                            (tid, phase, "trader_standing", None, None, None, ts["trader_slug"], None,
                             None, json.dumps({"standing": ts["standing"]})))
            for ou in r[phase]["offer_unlock"]:
                cur.execute("INSERT INTO task_rewards VALUES (?,?,?,?,?,?,?,?,?,?)",
                            (tid, phase, "offer_unlock", ou.get("bsg_id"), ou.get("name"), ou.get("count"),
                             ou["trader_slug"], None, ou.get("level"), None))
            for bu in r[phase]["barter_unlock"]:
                cur.execute("INSERT INTO task_rewards VALUES (?,?,?,?,?,?,?,?,?,?)",
                            (tid, phase, "barter_unlock", (bu.get("offered") or {}).get("bsg_id"),
                             (bu.get("offered") or {}).get("name"), (bu.get("offered") or {}).get("count"),
                             bu.get("trader_slug"), None, bu.get("min_trader_level"), json.dumps(bu)))
            for cu in r[phase]["craft_unlock"]:
                cur.execute("INSERT INTO task_rewards VALUES (?,?,?,?,?,?,?,?,?,?)",
                            (tid, phase, "craft_unlock", cu.get("bsg_id"), cu.get("name"), cu.get("count"),
                             None, cu.get("station_name"), cu.get("level"), None))
            for tu in r[phase]["trader_unlock"]:
                cur.execute("INSERT INTO task_rewards VALUES (?,?,?,?,?,?,?,?,?,?)",
                            (tid, phase, "trader_unlock", None, tu["trader_name"], None, tu["trader_slug"], None, None, None))
            for sl in r[phase]["skill_level_reward"]:
                cur.execute("INSERT INTO task_rewards VALUES (?,?,?,?,?,?,?,?,?,?)",
                            (tid, phase, "skill", None, sl.get("skill"), None, None, None, sl.get("level"), None))
            for ach in r[phase]["achievement"]:
                cur.execute("INSERT INTO task_rewards VALUES (?,?,?,?,?,?,?,?,?,?)",
                            (tid, phase, "achievement", ach.get("id"), ach.get("name"), None, None, None, None, None))
    stats["tasks"] = len(rows)
    stats["objectives"] = cur.execute("SELECT COUNT(*) FROM task_objectives").fetchone()[0]
    stats["reward_rows"] = cur.execute("SELECT COUNT(*) FROM task_rewards").fetchone()[0]

    # ---- hideout ---------------------------------------------------------
    rows = list(C.load_jsonl(os.path.join(C.CANON, "hideout_stations.ndjson")))
    cur.executemany("INSERT INTO hideout_stations VALUES (?,?,?,?,?)",
                    [(r["id"], r["slug"], r["name"], r["area_type"], r["image_url"]) for r in rows])
    for r in rows:
        for lv in r["levels"]:
            cur.execute("INSERT INTO hideout_levels VALUES (?,?,?)", (r["id"], lv["level"], lv["construction_time"]))
            for ir in lv["item_requirements"]:
                if ir.get("bsg_id"):
                    cur.execute("INSERT INTO hideout_level_items VALUES (?,?,?,?,?)",
                                (r["id"], lv["level"], ir["bsg_id"], ir.get("count"), int(bool(ir.get("found_in_raid")))))
            for sr in lv["station_level_requirements"]:
                cur.execute("INSERT INTO hideout_level_station_reqs VALUES (?,?,?,?)",
                            (r["id"], lv["level"], sr["station_id"], sr["level"]))
            for tr in lv["trader_requirements"]:
                cur.execute("INSERT INTO hideout_level_trader_reqs VALUES (?,?,?,?)",
                            (r["id"], lv["level"], tr["trader_slug"], tr["level"]))
    stats["hideout_stations"] = len(rows)

    # ---- maps ------------------------------------------------------------
    rows = list(C.load_jsonl(os.path.join(C.CANON, "maps.ndjson")))
    cur.executemany("INSERT INTO maps VALUES (?,?,?,?,?,?,?,?,?,?,?)",
                    [(r["id"], r["slug"], r["name"], r["name_id"], r["wiki_link"], r["raid_duration"],
                      r["players"], json.dumps(r["enemies"]), json.dumps(r["bosses"]),
                      json.dumps(r["extracts"]), json.dumps(r["transits"])) for r in rows])
    stats["maps"] = len(rows)

    # ---- items -----------------------------------------------------------
    n_items = n_slots = n_allowed = 0
    for r in C.load_jsonl(os.path.join(C.CANON, "items.ndjson")):
        props = r["properties"] or {}
        stats_block = r.get("stats") or {}
        phys, econ, wk = r["physical"], r["economy"], r.get("wiki") or {}
        cur.execute(
            "INSERT INTO items VALUES (" + ",".join("?" * 45) + ")",
            (
                r["bsg_id"], r["slug"], r["name"], r["short_name"], r["description"], r["name_source"],
                int(bool(r["quest_item"])), r["properties_type"],
                phys["width"], phys["height"], phys["weight"], phys["stack_max_size"], int(bool(phys["has_grid"])),
                phys["discard_limit"], phys["background_color"],
                econ["base_price"], econ["last_low_price"], econ["avg24h_price"], econ["low24h_price"],
                econ["high24h_price"], econ["change_last_48h"], econ["change_last_48h_percent"],
                econ["last_offer_count"], econ["min_level_for_flea"], econ["last_scan"],
                props.get("class") or stats_block.get("armorClass"),
                props.get("damage") or stats_block.get("damage"),
                props.get("penetrationPower") or stats_block.get("penetrationPower"),
                props.get("caliber") or stats_block.get("caliber"),
                props.get("ergonomics") or stats_block.get("ergonomicsModifier"),
                props.get("maxDurability") or stats_block.get("maxDurability"),
                props.get("uses"),
                r["links"]["tarkovdev"], r["links"]["wiki"], r["links"]["market"],
                json.dumps((r.get("market") or {}).get("tags") or []),
                r["images"]["icon"], r["images"]["grid"], r["images"]["market"],
                json.dumps(props, ensure_ascii=False), json.dumps(stats_block, ensure_ascii=False),
                json.dumps(r["conflicts"], ensure_ascii=False),
                json.dumps(wk.get("infobox") or {}, ensure_ascii=False),
                json.dumps(r.get("market"), ensure_ascii=False), json.dumps(r["sources"]),
            ),
        )
        cur.executemany("INSERT INTO item_types VALUES (?,?)", [(r["bsg_id"], t) for t in r["types"]])
        cur.executemany("INSERT INTO item_categories VALUES (?,?,?,?)",
                        [(r["bsg_id"], "item", cid, None) for cid in r["categories"]["ids"]]
                        + [(r["bsg_id"], "handbook", cid, None) for cid in r["handbook_categories"]["ids"]])
        cur.executemany("INSERT INTO item_sources VALUES (?,?)", [(r["bsg_id"], s) for s in r["sources"]])
        cur.executemany("INSERT INTO item_conflicts VALUES (?,?,?)",
                        [(r["bsg_id"], x, "tarkovdev") for x in r["conflicts"]["items"]]
                        + [(r["bsg_id"], x["bsg_id"], "officialwiki") for x in r["conflicts"]["wiki_items"] if x.get("bsg_id")])
        cur.executemany("INSERT INTO item_compatibility VALUES (?,?)",
                        [(r["bsg_id"], x["bsg_id"]) for x in r.get("compatibility") or [] if x.get("bsg_id")])
        wk = r.get("wiki") or {}
        if wk:
            cur.execute("INSERT OR REPLACE INTO item_wiki_meta VALUES (?,?,?,?,?)",
                        (r["bsg_id"], wk.get("internal_id"), wk.get("price"),
                         (wk.get("xp") or {}).get("loot_xp"), (wk.get("xp") or {}).get("exam_xp")))
            cur.executemany("INSERT INTO item_wiki_trader_offers VALUES (?,?,?,?,?,?)",
                            [(r["bsg_id"], o["trader_slug"], o["trader_name"], o.get("level_number"),
                              o.get("variant"), o.get("faction"))
                             for o in wk.get("trader_offers") or []])
        for wm in ((r.get("wiki") or {}).get("mod_slots") or []):
            cur.executemany("INSERT INTO item_wiki_slots VALUES (?,?,?)",
                            [(r["bsg_id"], wm.get("slot"), x["bsg_id"]) for x in (wm.get("items") or []) if x.get("bsg_id")])
        cur.executemany("INSERT INTO item_grids VALUES (?,?,?,?,?)",
                        [(r["bsg_id"], g["width"], g["height"], json.dumps(g["allowed_categories"]),
                          json.dumps(g["allowed_items"])) for g in (r.get("grids") or [])])
        cur.executemany("INSERT INTO item_contained VALUES (?,?,?)",
                        [(r["bsg_id"], c["bsg_id"], c.get("count")) for c in r["contains_items"] if c.get("bsg_id")])
        for slot in (r.get("slots") or []):
            sid = f'{r["bsg_id"]}:{slot.get("id") or slot.get("name_id")}'
            allowed = slot["filters"]["allowed_items"]
            cur.execute("INSERT OR REPLACE INTO item_slots VALUES (?,?,?,?,?,?)",
                        (sid, r["bsg_id"], slot.get("name_id"), slot.get("name"),
                         int(bool(slot.get("required"))), len(allowed)))
            cur.executemany("INSERT INTO item_slot_allowed VALUES (?,?)", [(sid, a) for a in allowed])
            n_slots += 1
            n_allowed += len(allowed)
        for direction, key in (("buy_from", "buy_from"), ("sell_to", "sell_to")):
            cur.executemany("INSERT INTO item_trade VALUES (?,?,?,?,?,?,?,?,?)",
                            [(r["bsg_id"], direction, t["trader_slug"], t["price"], t["price_rub"],
                              t["currency"], t.get("min_trader_level"), t.get("task_unlock_id"), t.get("buy_limit"))
                             for t in r["trade"][key]])
        acq = r["acquisition"]
        cur.executemany("INSERT INTO item_acquisition VALUES (?,?,?,?,?,?,?,?)",
                        [(r["bsg_id"], "buy", None, b["trader_slug"], None, b.get("min_trader_level"), None, json.dumps(b))
                         for b in acq["buy"]]
                        + [(r["bsg_id"], "buy_index", None, b["trader_slug"], None, b.get("level"), None, json.dumps(b))
                           for b in acq["index_offers"]]
                        + [(r["bsg_id"], "barter", b["barter_id"], b["trader_slug"], None, b["min_trader_level"], None,
                            json.dumps(b)) for b in acq["barter"]]
                        + [(r["bsg_id"], "craft", c["craft_id"], None, c["station_name"], c["level"], None,
                            json.dumps(c)) for c in acq["craft"]]
                        + [(r["bsg_id"], "task_reward", t["task_id"], None, None, None, t.get("count"),
                            json.dumps(t)) for t in acq["task_rewards"]]
                        )
        used = r["used_in"]
        cur.executemany("INSERT INTO item_used_in VALUES (?,?,?,?,?,?)",
                        [(r["bsg_id"], "craft", c["craft_id"], (c.get("product") or {}).get("name"), None, json.dumps(c))
                         for c in used["crafts"]]
                        + [(r["bsg_id"], "barter", b["barter_id"], (b.get("offered") or {}).get("name"), None, json.dumps(b))
                           for b in used["barters"]]
                        + [(r["bsg_id"], "hideout_build", h["station_id"], h["station_name"], h["count"], None)
                           for h in used["hideout_build"]]
                        + [(r["bsg_id"], "task_objective", o["task_id"], o["task_name"], None, o["type"])
                           for o in used["task_objectives"]])
        cur.execute("INSERT INTO items_fts VALUES (?,?,?,?)",
                    (r["bsg_id"], r["name"] or "", r["short_name"] or "", r["slug"] or ""))
        n_items += 1
    stats["items"] = n_items
    stats["item_slots"] = n_slots
    stats["slot_allowed"] = n_allowed

    # ---- weapon variants -------------------------------------------------
    rows = list(C.load_jsonl(os.path.join(C.CANON, "weapon_variants.ndjson")))
    cur.executemany("INSERT OR REPLACE INTO weapon_variants VALUES (?,?,?,?,?)",
                    [(r["base_bsg_id"], r["name"], r["preset_bsg_id"], r["preset_slug"],
                      len(r["attachments"])) for r in rows])
    for r in rows:
        cur.executemany("INSERT INTO weapon_variant_attachments VALUES (?,?,?)",
                        [(r["base_bsg_id"], r["name"], a["bsg_id"]) for a in r["attachments"] if a.get("bsg_id")])
    stats["weapon_variants"] = len(rows)

    # ---- reference -------------------------------------------------------
    ref = json.load(open(os.path.join(C.CANON, "reference.json"), encoding="utf-8"))
    cur.executemany("INSERT INTO player_levels VALUES (?,?,?)",
                    [(p["level"], p["exp"], p.get("levelBadgeImageLink")) for p in (ref.get("player_levels") or [])])
    cur.executemany("INSERT INTO skills VALUES (?,?,?,?,?)",
                    [(s["id"], s.get("name"), s.get("normalizedName"), s.get("wikiLink"), s.get("imageLink"))
                     for s in (ref.get("skills") or [])])
    cur.executemany("INSERT INTO armor_materials VALUES (?,?,?,?,?,?,?,?)",
                    [(k, v.get("name"), v.get("destructibility"), v.get("explosionDestructibility"),
                      v.get("maxRepairDegradation"), v.get("maxRepairKitDegradation"),
                      v.get("minRepairDegradation"), v.get("minRepairKitDegradation"))
                     for k, v in (ref.get("armor_materials") or {}).items()])
    cur.executemany("INSERT INTO mastery VALUES (?,?)",
                    [(m["id"], json.dumps(m.get("weapons") or [])) for m in (ref.get("mastering") or [])])
    cur.executemany("INSERT INTO achievements VALUES (?,?,?,?,?,?,?,?)",
                    [(a["id"], a.get("name"), a.get("slug"), a.get("description"), int(bool(a.get("hidden"))),
                      a.get("side"), a.get("rarity"), a.get("players_completed_percent"))
                     for a in (ref.get("achievements") or [])])
    for key in ("settings", "flea_market", "prestige", "special_items"):
        cur.execute("INSERT INTO settings VALUES (?,?)", (key, json.dumps(ref.get(key), ensure_ascii=False)))

    # backfill the denormalized path on item<->category links
    cur.execute("UPDATE item_categories SET path = ("
                "SELECT c.path FROM categories c WHERE c.id = item_categories.category_id AND c.kind = item_categories.kind)")
    con.executescript(VIEWS)
    con.commit()
    db_size = os.path.getsize(C.SQLITE)
    integrity = cur.execute("PRAGMA integrity_check").fetchone()[0]
    fk_check = cur.execute("PRAGMA foreign_key_check").fetchall() if False else []
    con.close()

    lines = ["# SQLite build", "", f"- `tarkov.sqlite3` — {db_size / 1e6:.1f} MB",
             f"- integrity_check: `{integrity}`", "", "## Row counts", "", "| table | rows |", "| --- | ---: |"]
    con = sqlite3.connect(C.SQLITE)
    tables = [r[0] for r in con.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE '%_fts%' ORDER BY name")]
    for t in tables:
        lines.append(f"| {t} | {con.execute(f'SELECT COUNT(*) FROM {t}').fetchone()[0]} |")
    con.close()
    os.makedirs(C.REPORTS, exist_ok=True)
    with open(os.path.join(C.REPORTS, "03_sqlite_stats.md"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
    print("\n".join(lines))
    print("\nbuild stats:", json.dumps(stats))


if __name__ == "__main__":
    main()
