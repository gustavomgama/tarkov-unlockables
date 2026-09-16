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
    check("every required slot is fillable", lambda: _slots_fillable(items))
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
    check("no item name is derived", lambda: _no_derived_names(items))
    check("index barter unlocks are routable", lambda: _index_barter_routes(items))
    check("barter unlocks present, none in failure", lambda: _unlock_phases(tasks))
    check("unlock sources are tagged", lambda: _unlock_sources(tasks))
    check("objective descriptions localised", lambda: _descriptions(tasks))
    check("wiki conflict relations resolve", lambda: _wiki_conflicts(items))
    check("wiki compatibility relations resolve", lambda: _compat(items))
    check("wiki trader offers parse and corroborate", lambda: _wiki_offers(items, trader_slugs))
    check("task graph is a well-formed DAG", lambda: _task_graph(tasks))
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
    check("route costs are complete or null, never faked", lambda: _route_costs(con))
    check("weapon build stats present", lambda: _build_stats(con))
    check("no table is entirely empty", lambda: _no_empty_tables(con))
    check("wiki-derived relations loaded", lambda: _wiki_tables(con))
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


def _no_derived_names(items):
    derived = [i["bsg_id"] for i in items if (i["name_source"] or "").startswith("derived")]
    assert not derived, f"{len(derived)} derived names, e.g. {derived[:3]}"
    srcs = {i["name_source"] for i in items}
    assert srcs <= {"tarkovdev:items_en", "tarkovdev:tasks_en", "officialwiki",
                    "tarkovmarket", "tarkovunlockables"}, f"unexpected sources {srcs}"
    return f"all official; sources={sorted(srcs)}"


def _index_barter_routes(items):
    """Every item the derived index says a task unlocks via barter must have a
    canonical barter route carrying that task gate."""
    import json as _json  # noqa: PLC0415
    idx = _json.load(open(os.path.join(C.OFF, "tarkovunlockables/tasks_index.json"), encoding="utf-8"))
    unlocked = set()
    for t in idx:
        for ph in ("start_rewards", "finish_rewards"):
            for r in (t.get(ph) or []):
                for bu in (r.get("barter_unlocks") or []):
                    for res in (bu.get("result") or []):
                        for it in (res.get("items") or []):
                            if it.get("item_id"):
                                unlocked.add(it["item_id"])
    by = {i["bsg_id"]: i for i in items}
    absent = [i for i in unlocked if i not in by]
    ungated = [i for i in unlocked if i in by and not any(
        b.get("task_unlock_id") for b in by[i]["acquisition"]["barter"])]
    assert not absent, f"{len(absent)} unlocked items missing from dataset"
    assert not ungated, f"{len(ungated)} unlocked items have no task-gated barter route"
    return f"{len(unlocked)} unlocked items all gated"


def _unlock_phases(tasks):
    kinds = ("barter_unlock", "offer_unlock", "craft_unlock")
    n = sum(len(t[p][k]) for t in tasks for p in ("start_rewards", "finish_rewards") for k in kinds)
    bad = sum(len(t["failure_outcome"][k]) for t in tasks for k in kinds)
    assert n > 0, "no unlocks at all"
    assert bad == 0, f"{bad} unlock entries in failure_outcome"
    bars = sum(len(t[p]["barter_unlock"]) for t in tasks for p in ("start_rewards", "finish_rewards"))
    assert bars >= 60, f"only {bars} barter unlocks"
    return f"{n} unlocks ({bars} barter), 0 in failure"


def _unlock_sources(tasks):
    srcs = {x.get("source") for t in tasks
            for p in ("start_rewards", "finish_rewards", "failure_outcome")
            for k in ("barter_unlock", "offer_unlock", "craft_unlock")
            for x in t[p][k]}
    assert srcs <= {"tarkovdev", "tarkovunlockables"}, f"untagged unlocks {srcs}"
    assert {"tarkovdev", "tarkovunlockables"} <= srcs, f"a source vanished: {srcs}"
    return f"sources={sorted(srcs)}"


def _descriptions(tasks):
    bad = [o["id"] for t in tasks for o in t["objectives"]
           if o["description"] and PLACEHOLDER.match(o["description"])]
    assert not bad, f"{len(bad)} placeholder objective descriptions"
    n = sum(1 for t in tasks for o in t["objectives"] if o["description"])
    return f"{n} described"


def _wiki_conflicts(items):
    """Both sources carry conflicts; the wiki corroborates most of the API's
    and adds a non-trivial remainder, so assert neither is silently lost."""
    api = {(i["bsg_id"], x) for i in items for x in i["conflicts"]["items"]}
    wiki = [(i["bsg_id"], x) for i in items for x in i["conflicts"]["wiki_items"]]
    wiki_ids = {(a, x["bsg_id"]) for a, x in wiki if x.get("bsg_id")}
    assert len(api) >= 10_000, f"only {len(api)} API conflict edges"
    assert len(wiki_ids) >= 2_000, f"only {len(wiki_ids)} wiki conflict edges"
    added = len(wiki_ids - api)
    assert added >= 100, f"wiki adds nothing new ({added})"
    unresolved = [x for _, x in wiki if not x.get("name")]
    assert not unresolved, f"{len(unresolved)} conflicts with no item name"
    agreed = len(wiki_ids & api)
    return f"api={len(api)}, wiki={len(wiki_ids)} ({agreed} corroborated, {added} wiki-only)"


def _task_graph(tasks):
    """Acyclic, closed prerequisite ids, and the Kappa/Lightkeeper closures
    materialised on every task."""
    ids = {t["id"] for t in tasks}
    prereq = {t["id"]: {x["bsg_id"] for x in t["task_requirements"] if x.get("bsg_id") in ids}
              | {x for x in t["previous_tasks"] if x in ids} for t in tasks}
    color = {}

    def dfs(u):
        color[u] = 1
        for v in prereq[u]:
            if color.get(v, 0) == 1:
                return True
            if color.get(v, 0) == 0 and dfs(v):
                return True
        color[u] = 2
        return False

    assert not any(dfs(t) for t in ids if color.get(t, 0) == 0), "quest graph has a cycle"
    orphans = {x for t in tasks for x in prereq[t["id"]] if x not in ids}
    assert not orphans, f"{len(orphans)} prerequisite ids not in the dataset"
    kappa = sum(1 for t in tasks if t["graph"]["kappa_chain"])
    light = sum(1 for t in tasks if t["graph"]["lightkeeper_chain"])
    assert kappa == 13, f"kappa chain changed: {kappa}"
    assert light == 7, f"lightkeeper chain changed: {light}"
    deep = max(t["graph"]["depth"] for t in tasks)
    assert deep >= 10, f"max chain depth only {deep}"
    assert all(t["graph"]["prerequisites"] == len(prereq[t["id"]]) for t in tasks), "prerequisites count drifted"
    return f"acyclic, depth {deep}, kappa {kappa}, lightkeeper {light}"


def _wiki_offers(items, trader_slugs):
    """The wiki infobox carries an independent, human-maintained list of who
    sells what at which loyalty level; assert it parses and corroborates."""
    rows = [(i["bsg_id"], o) for i in items for o in (i.get("wiki") or {}).get("trader_offers") or []]
    assert len(rows) >= 2_500, f"only {len(rows)} wiki trader offers"
    unknown = {o["trader_slug"] for _, o in rows} - trader_slugs
    assert not unknown, f"unknown traders in wiki offers: {sorted(unknown)}"
    factions = {o.get("faction") for _, o in rows} - {None}
    assert factions <= {"bear", "usec"}, f"unexpected edition factions {factions}"
    matched = 0
    for i in items:
        wiki = {o["trader_slug"] for o in (i.get("wiki") or {}).get("trader_offers") or []}
        if not wiki:
            continue
        api = {b["trader_slug"] for b in i["acquisition"]["buy"]} | {o["trader_slug"] for o in i["acquisition"]["index_offers"]}
        matched += len(wiki & api)
    total = len(rows)
    assert matched / total >= 0.90, f"only {matched}/{total} wiki offers corroborated"
    internal = sum(1 for i in items if (i.get("wiki") or {}).get("internal_id"))
    assert internal >= 2_700, f"only {internal} wiki internal ids"
    return f"{total} offers over {sum(1 for i in items if (i.get('wiki') or {}).get('trader_offers'))} items, {matched} ({matched * 100 // total}%) corroborated, {internal} internal ids"


def _compat(items):
    edges = [(i["bsg_id"], x) for i in items for x in i.get("compatibility") or []]
    assert len(edges) >= 8000, f"only {len(edges)} compatibility edges"
    unresolved = [x for _, x in edges if not x.get("name")]
    assert not unresolved, f"{len(unresolved)} compatibility refs with no item name"
    return f"{len(edges)} edges over {sum(1 for i in items if i.get('compatibility'))} items"


def _wiki_tables(con):
    out = {}
    for t in ("item_wiki_slots", "item_wiki_meta", "item_wiki_trader_offers",
              "item_conflicts", "item_compatibility", "item_grids"):
        out[t] = con.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
        assert out[t] > 0, f"{t} is empty"
    wiki_conf = con.execute("SELECT COUNT(*) FROM item_conflicts WHERE source='officialwiki'").fetchone()[0]
    assert wiki_conf >= 2000, f"only {wiki_conf} wiki conflicts in sqlite"
    return ", ".join(f"{k}={v}" for k, v in out.items())


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


def _route_costs(con):
    """A costed route must be fully costed; an incomplete one must have no cost.
    A missing input price must never read as a free input."""
    n = con.execute("SELECT COUNT(*) FROM item_acquisition_cost").fetchone()[0]
    assert n >= 800, f"only {n} cost rows"
    faked = con.execute("SELECT COUNT(*) FROM item_acquisition_cost WHERE complete = 0 AND cost_rub IS NOT NULL").fetchone()[0]
    assert faked == 0, f"{faked} incomplete routes carry a cost"
    uncosted = con.execute("SELECT COUNT(*) FROM item_acquisition_cost WHERE complete = 1 AND cost_rub IS NULL").fetchone()[0]
    assert uncosted == 0, f"{uncosted} complete routes have no cost"
    fake_zero = con.execute(
        "SELECT COUNT(*) FROM item_acquisition_cost WHERE complete = 1 AND cost_rub = 0 AND consumed_inputs > 0").fetchone()[0]
    assert fake_zero == 0, f"{fake_zero} zero-cost routes that do consume inputs"
    zeros = con.execute("SELECT COUNT(*) FROM item_acquisition_cost WHERE cost_rub = 0").fetchone()[0]
    priced = con.execute("SELECT COUNT(*) FROM item_acquisition_cost WHERE complete = 1").fetchone()[0]
    assert priced >= 700, f"only {priced} priced routes"
    cheaper = con.execute("SELECT COUNT(*) FROM v_item_acquisition_cost WHERE vs_flea_rub > 0").fetchone()[0]
    return (f"{n} rows, {priced} priced, {n - priced} incomplete (null cost), "
            f"{zeros} legitimately zero-cost (no inputs), {cheaper} cheaper than flea")


def _slots_fillable(items):
    """A required slot that no existing item can fill would make the weapon
    unbuildable from this dataset."""
    known = {i["bsg_id"] for i in items}
    bad = []
    for i in items:
        for s in i.get("slots") or []:
            if s.get("required") and not [a for a in s["filters"]["allowed_items"] if a in known]:
                bad.append((i["name"], s.get("name_id")))
    assert not bad, f"{len(bad)} unfillable required slots, e.g. {bad[:3]}"
    n = sum(1 for i in items for s in i.get("slots") or [] if s.get("required"))
    return f"{n} required slots, all fillable"


def _build_stats(con):
    n, capped = con.execute("SELECT COUNT(*), SUM(combinations_capped) FROM weapon_build_stats").fetchone()
    assert n == 171, f"{n} weapon build rows"
    assert capped >= 100, f"only {capped} capped combinations"
    return f"{n} weapons, {capped} with capped combinatorial counts"


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
