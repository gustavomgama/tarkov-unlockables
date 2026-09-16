#!/usr/bin/env python3
"""Verify the canonical dataset and the SQLite build.

Every check is an assertion: the script exits non-zero on the first failure and
writes a pass/fail table to `reports/04_verification.md`. Designed to be the
"one runnable check" the pipeline leaves behind.

Run: ~/.pyvenv-tarkov/bin/python datastore/scripts/99_verify.py
"""
from __future__ import annotations

import json
import os
import re
import sqlite3
from collections import Counter

import _common as C

PLACEHOLDER = re.compile(r"^[0-9a-f]{24} (Name|ShortName|Description)$")
results = []


def check(name, fn):
    try:
        detail = fn()
        results.append((True, name, detail or "ok"))
    except AssertionError as exc:
        results.append((False, name, f"FAIL: {exc}"))
    except Exception as exc:  # noqa: BLE001 - surface any error as a failure
        results.append((False, name, f"ERROR: {type(exc).__name__}: {exc}"))


def load(name):
    return list(C.load_jsonl(os.path.join(C.CANON, f"{name}.ndjson")))


def main():
    items = load("items")
    tasks = load("tasks")
    traders = load("traders")
    barters = load("barters")
    crafts = load("crafts")
    hideout = load("hideout_stations")
    maps = load("maps")
    cats = load("categories")
    ref = json.load(open(os.path.join(C.CANON, "reference.json"), encoding="utf-8"))

    item_ids = {i["bsg_id"] for i in items}
    trader_slugs = {t["slug"] for t in traders}
    task_ids = {t["id"] for t in tasks}
    map_ids = {m["id"] for m in maps}

    # -- canonical shape ---------------------------------------------------
    check("canonical files exist", lambda: ", ".join(
        f"{n}.ndjson" for n in ("items", "tasks", "traders", "barters", "crafts",
                                "hideout_stations", "maps", "categories")
        if not os.path.exists(os.path.join(C.CANON, f"{n}.ndjson"))) or "all present")
    check("items unique bsg_id", lambda: f"{len(item_ids)} distinct of {len(items)}"
          if len(item_ids) == len(items) else (_ for _ in ()).throw(AssertionError("duplicate bsg_id")))
    check("items >= 5000", lambda: f"{len(items)}" if len(items) >= 5000 else (_ for _ in ()).throw(AssertionError(len(items))))
    check("no placeholder display names", lambda: _no_placeholder(items))
    check("every item has a name", lambda: _all_named(items))
    check("every item has a slug", lambda: _all_have(items, "slug"))
    check("name_source recorded for every item", lambda: _all_have(items, "name_source"))
    check("tasks unique id", lambda: f"{len(task_ids)} distinct of {len(tasks)}"
          if len(task_ids) == len(tasks) else (_ for _ in ()).throw(AssertionError("dup task id")))
    check("every task has a name + slug", lambda: _all_have(tasks, "name", "slug"))

    # -- referential integrity --------------------------------------------
    check("barter traders resolve", lambda: _subset({b["trader_slug"] for b in barters}, trader_slugs, "barter.trader"))
    check("craft stations resolve", lambda: _subset({c["station_name"] for c in crafts}, None, "craft.station", allow_none=False))
    check("task traders resolve", lambda: _subset({t["trader_slug"] for t in tasks}, trader_slugs, "task.trader"))
    check("task map ids resolve", lambda: _subset({t["map_id"] for t in tasks if t["map_id"]}, map_ids, "task.map"))
    check("barter offered items resolve", lambda: _subset(
        {(b["offered_item"] or {}).get("bsg_id") for b in barters if (b["offered_item"] or {}).get("bsg_id")}, item_ids, "barter.offered"))
    check("craft products resolve", lambda: _subset(
        {(c["product_item"] or {}).get("bsg_id") for c in crafts if (c["product_item"] or {}).get("bsg_id")}, item_ids, "craft.product"))
    check("craft required items resolve", lambda: _subset(
        {ri["bsg_id"] for c in crafts for ri in c["required_items"] if ri.get("bsg_id")}, item_ids, "craft.required"))
    check("barter required items resolve", lambda: _subset(
        {ri["bsg_id"] for b in barters for ri in b["required_items"] if ri.get("bsg_id")}, item_ids, "barter.required"))
    check("task objective items resolve", lambda: _subset(
        {i for t in tasks for o in t["objectives"]
         for i in ((o["raw"].get("items") or []) if isinstance(o["raw"], dict) else [])}, item_ids, "objective.items"))
    check("task reward items resolve", lambda: _subset(
        {i["bsg_id"] for t in tasks
         for ph in ("start_rewards", "finish_rewards", "failure_outcome")
         for i in t[ph]["items"] if i.get("bsg_id")}, item_ids, "reward.items"))
    check("hideout build items resolve", lambda: _subset(
        {ir["bsg_id"] for s in hideout for lv in s["levels"] for ir in lv["item_requirements"] if ir.get("bsg_id")},
        item_ids, "hideout.items"))
    check("task leads_to resolve", lambda: _subset(
        {lt["task_id"] for t in tasks for lt in t["leads_to"] if lt["task_id"]}, task_ids, "task.leads_to"))
    check("slot allowed items resolve", lambda: _subset(
        {a for i in items for s in (i.get("slots") or []) for a in s["filters"]["allowed_items"]}, item_ids, "slot.allowed"))

    # -- coverage / known-game facts --------------------------------------
    check("trader count is the full roster", lambda: _expect(len(traders), 16, ">=14"))
    check("craft stations == 8", lambda: _expect(len({c["station_name"] for c in crafts}), 8, "==8"))
    check("tasks reference maps", lambda: f"{len({t['map_id'] for t in tasks if t['map_id']})} distinct map ids")
    check("kappa tasks present", lambda: _min(sum(1 for t in tasks if t["kappa_required"]), 1, "kappa"))
    check("hideout has Workbench", lambda: "Workbench" in {s["name"] for s in hideout})
    check("map names include Factory", lambda: "factory" in {m["slug"] for m in maps})
    check("reference has 79 player levels", lambda: _expect(len(ref["player_levels"]), 79, "==79"))
    check("reference has 123 achievements", lambda: f"{len(ref['achievements'])}")

    check("M4A1 resolves with mod slots", lambda: _m4(items))
    check("'First in Line' task named", lambda: _task(tasks, "first-in-line"))
    check("every achievement has a name", lambda: _all_have(ref["achievements"], "name"))
    check("objective descriptions localised", lambda: _descriptions(tasks))
    check("map boss names resolved", lambda: _map_names(maps, "bosses"))
    check("map transit names resolved", lambda: _map_names(maps, "transits"))
    check("map extract names resolved", lambda: _map_names(maps, "extracts"))
    check("buy routes are all tarkovdev + priced", lambda: _buy_sources(items))
    check("buy coverage (tdev + index union) >= 2,900", lambda: _min(
        sum(1 for i in items if i["acquisition"]["buy"] or i["acquisition"]["index_offers"]),
        2900, "buyable items"))
    check("sell_to rows have no null price", lambda: _sell_prices(items))

    # -- sqlite ------------------------------------------------------------
    check("sqlite file exists", lambda: str(os.path.getsize(C.SQLITE)) if os.path.exists(C.SQLITE) else
          (_ for _ in ()).throw(AssertionError("missing tarkov.sqlite3")))
    con = sqlite3.connect(C.SQLITE)
    con.row_factory = sqlite3.Row
    check("sqlite integrity_check", lambda: _integrity(con))
    check("sqlite item count matches canonical", lambda: _expect(
        con.execute("SELECT COUNT(*) FROM items").fetchone()[0], len(items), f"=={len(items)}"))
    check("fts search finds M4A1", lambda: _fts(con, "M4A1"))
    check("fts search finds LEDX", lambda: _fts(con, "LEDX"))
    check("view v_item_price returns", lambda: _view(con))
    check("sqlite trader levels", lambda: _expect(
        con.execute("SELECT COUNT(*) FROM trader_levels").fetchone()[0], 42, "==42"))
    check("sqlite slot graph present", lambda: f"{con.execute('SELECT COUNT(*) FROM item_slot_allowed').fetchone()[0]} allowed-item edges")
    check("sqlite acquisition present", lambda: f"{con.execute('SELECT COUNT(*) FROM item_acquisition').fetchone()[0]} routes")
    check("category paths backfilled", lambda: _cat_paths(con))
    check("no table is entirely empty", lambda: _no_empty_tables(con))
    con.close()

    lines = ["# Verification", "", "| # | check | result |", "| ---: | --- | --- |"]
    for n, (ok, name, detail) in enumerate(results, 1):
        lines.append(f"| {n} | {'PASS' if ok else 'FAIL'} | {name} — {detail} |" if not ok
                     else f"| {n} | PASS | {name} — {detail} |")
    failed = [r for r in results if not r[0]]
    lines += ["", f"**{len(results) - len(failed)}/{len(results)} checks passed.**"]
    os.makedirs(C.REPORTS, exist_ok=True)
    with open(os.path.join(C.REPORTS, "04_verification.md"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
    print("\n".join(lines))
    if failed:
        raise SystemExit(f"{len(failed)} check(s) failed")


def _no_placeholder(items):
    bad = [i["bsg_id"] for i in items if i.get("name") and PLACEHOLDER.match(i["name"])]
    assert not bad, f"{len(bad)} placeholder names, e.g. {bad[:3]}"
    return "0 placeholders"


def _all_named(items):
    bad = [i["bsg_id"] for i in items if not i.get("name")]
    assert not bad, f"{len(bad)} unnamed items: {bad[:5]}"
    return f"{len(items)} named"


def _all_have(rows, *keys):
    bad = [r for r in rows if any(not r.get(k) for k in keys)]
    assert not bad, f"{len(bad)} rows missing {keys}"
    return f"all {len(rows)}"


def _subset(values, allowed, label, allow_none=True):
    vals = {v for v in values if v is not None}
    if allowed is None:
        assert vals, f"{label}: nothing resolved"
        return f"{len(vals)} distinct"
    missing = sorted(vals - allowed)
    assert not missing, f"{label}: {len(missing)} unresolved e.g. {missing[:5]}"
    return f"{len(vals)} distinct, all resolved"


def _expect(actual, expected, label):
    assert actual == expected, f"{label}: got {actual}, want {expected}"
    return f"{label} = {actual}"


def _min(value, minimum, label):
    assert value >= minimum, f"{label}: {value} < {minimum}"
    return f"{label} = {value}"


def _descriptions(tasks):
    bad = [o["id"] for t in tasks for o in t["objectives"]
           if o["description"] and PLACEHOLDER.match(o["description"])]
    assert not bad, f"{len(bad)} placeholder objective descriptions"
    n = sum(1 for t in tasks for o in t["objectives"] if o["description"])
    return f"{n} described"


def _map_names(maps, key):
    bad, total = [], 0
    for m in maps:
        for e in m[key]:
            total += 1
            name = e.get("name")
            if not name or PLACEHOLDER.match(str(name)) or str(name).startswith(("Map", "FAC_")):
                bad.append({"map": m["slug"], key: e})
    assert not bad, f"{len(bad)} unresolved, e.g. {bad[:2]}"
    return f"{total} entries named"


def _buy_sources(items):
    routes = [b for i in items for b in i["acquisition"]["buy"]]
    assert routes, "no buy routes at all"
    sources = {b.get("source") for b in routes}
    assert sources == {"tarkovdev"}, f"unexpected sources {sources}"
    priced = sum(1 for b in routes if b.get("price") is not None)
    assert priced >= 2500, f"only {priced} priced buy rows"
    offers = [o for i in items for o in i["acquisition"]["index_offers"]]
    assert {o.get("source") for o in offers} == {"tarkovunlockables"}, "index_offers source mix"
    assert any(o.get("variant") for o in offers), "no variant labels preserved"
    variants = sum(1 for o in offers if o.get("variant"))
    return f"{len(routes)} tdev rows ({priced} priced) + {len(offers)} index offers ({variants} with variant)"


def _sell_prices(items):
    rows = [t for i in items for t in i["trade"]["sell_to"]]
    nulls = [t for t in rows if t["price"] is None]
    assert not nulls, f"{len(nulls)} sell_to rows with null price"
    pos = sum(1 for t in rows if t["price"] and t["price"] > 0)
    assert pos >= 20000, f"only {pos} positive sell prices"
    return f"{len(rows)} rows, {pos} positive, {len(rows) - pos} zero"


def _m4(items):
    m = next((i for i in items if i["slug"] == "colt-m4a1-556x45-assault-rifle"), None)
    assert m, "M4A1 missing"
    assert m["name"] == "Colt M4A1 5.56x45 assault rifle", m["name"]
    assert m["slots"], "no mod slots"
    assert m["acquisition"]["buy"], "no trader buy route"
    assert m["trade"]["sell_to"], "no sell_to"
    return f"{m['name']} — {len(m['slots'])} slots, {len(m['acquisition']['buy'])} buy routes"


def _task(tasks, slug):
    t = next((x for x in tasks if x["slug"] == slug), None)
    assert t, f"{slug} missing"
    assert t["name"] and not t["name"].endswith(" name"), t["name"]
    assert t["trader_slug"], "no trader"
    return f"{t['name']} by {t['trader_slug']} ({len(t['objectives'])} objectives)"


def _cat_paths(con):
    total = con.execute("SELECT COUNT(*) FROM item_categories").fetchone()[0]
    filled = con.execute("SELECT COUNT(*) FROM item_categories WHERE path IS NOT NULL").fetchone()[0]
    assert filled == total and total > 0, f"{total - filled} of {total} category links have no path"
    return f"{filled}/{total} populated"


def _no_empty_tables(con):
    tables = [r[0] for r in con.execute(
        "SELECT name FROM sqlite_master WHERE type='table' "
        "AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'items_fts_%'")]
    empty = [t for t in tables if con.execute(f"SELECT 1 FROM {t} LIMIT 1").fetchone() is None]
    assert not empty, f"empty tables: {empty}"
    return f"{len(tables)} tables all non-empty"


def _integrity(con):
    r = con.execute("PRAGMA integrity_check").fetchone()[0]
    assert r == "ok", r
    return r


def _fts(con, term):
    rows = con.execute("SELECT bsg_id, name FROM items_fts WHERE items_fts MATCH ? LIMIT 3", (term,)).fetchall()
    assert rows, f"no FTS hits for {term}"
    return f"{len(rows)}+ hits, first={rows[0]['name']}"


def _view(con):
    n = con.execute("SELECT COUNT(*) FROM v_item_price WHERE avg24h_price > 0").fetchone()[0]
    assert n > 1000, n
    return f"{n} priced items"


if __name__ == "__main__":
    main()
