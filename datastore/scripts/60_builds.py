#!/usr/bin/env python3
"""Weapon build analysis over the mod graph.

A weapon's `slots[].filters.allowed_items` *is* its build tree: fill each slot
with one allowed item, and each of those items may have slots of its own. This
script walks that graph to

  1. count how many distinct valid configurations each weapon has (a product
     over slots, recursively), capped — the numbers explode fast, and
  2. find required slots that no existing item can fill, which would make a
     weapon unbuildable from the dataset.

Cycles (a mod whose slot accepts its own ancestors) are cut, and capped counts
are flagged rather than reported as exact.

Writes `reports/07_weapon_builds.md` and the `weapon_build_stats` table.

Run: ~/.pyvenv-tarkov/bin/python datastore/scripts/60_builds.py
"""
from __future__ import annotations

import os
import sqlite3
from collections import Counter

import _common as C

CAP = 10**12
L = []


def p(*a):
    L.append(" ".join(str(x) for x in a))


def main():
    items = list(C.load_jsonl(os.path.join(C.CANON, "items.ndjson")))
    slots = {i["bsg_id"]: (i.get("slots") or []) for i in items}
    known = set(slots)
    weapons = [i for i in items if i["properties_type"] == "ItemPropertiesWeapon"]

    unfillable = []

    def combos(item_id, visiting):
        """(count_or_CAP, capped) for a fully-assembled configuration of item."""
        if item_id in visiting:
            return 1, False                      # cycle cut: treat as terminal
        visiting = visiting | {item_id}
        total, capped = 1, False
        for slot in slots.get(item_id, []):
            allowed = [a for a in slot["filters"]["allowed_items"] if a in known]
            if slot.get("required") and not allowed:
                unfillable.append((item_id, slot.get("name_id")))
            options = 1                          # leaving the slot empty
            for a in allowed:
                n, c = combos(a, visiting)
                options += n
                capped = capped or c
                if options >= CAP:
                    options, capped = CAP, True
            total *= options
            if total >= CAP:
                total, capped = CAP, True
        return total, capped

    rows = []
    for w in weapons:
        wid = w["bsg_id"]
        n, capped = combos(wid, frozenset())
        req = sum(1 for s in slots[wid] if s.get("required"))
        opt = len(slots[wid]) - req
        rows.append((wid, req, opt, None if capped else n, int(capped)))

    con = sqlite3.connect(C.SQLITE)
    con.executescript("""
        DROP TABLE IF EXISTS weapon_build_stats;
        CREATE TABLE weapon_build_stats (
          bsg_id TEXT PRIMARY KEY, required_slots INTEGER, optional_slots INTEGER,
          build_combinations INTEGER, combinations_capped INTEGER
        );
        CREATE INDEX idx_build_stats ON weapon_build_stats(build_combinations);
    """)
    con.executemany("INSERT OR REPLACE INTO weapon_build_stats VALUES (?,?,?,?,?)", rows)
    con.commit()
    con.close()

    by_id = {i["bsg_id"]: i for i in items}
    capped_n = sum(1 for r in rows if r[4])
    exact = [r for r in rows if not r[4]]

    p("# Weapon build analysis")
    p()
    p(f"- weapons (`ItemPropertiesWeapon`): **{len(weapons)}**")
    p(f"- with at least one mod slot: **{sum(1 for r in rows if r[1] + r[2])}**")
    p(f"- configurations too large to count exactly (capped at {CAP:,}): **{capped_n}**")
    p(f"- number of distinct valid configurations for the largest exact build: "
      f"**{max((r[3] for r in exact), default=0):,}**")
    p()

    p("## Weapons with the most build options")
    p()
    p("| weapon | required slots | optional slots | configurations |")
    p("| --- | ---: | ---: | ---: |")
    for r in sorted(rows, key=lambda r: (r[4], r[3] if r[3] is not None else CAP), reverse=True)[:20]:
        shown = "> 1,000,000,000,000 (capped)" if r[4] else f"{r[3]:,}"
        p(f"| {by_id[r[0]]['name']} | {r[1]} | {r[2]} | {shown} |")
    p()

    p("## Exact build counts (most constrained weapons with slots)")
    p()
    p("| weapon | required slots | optional slots | configurations |")
    p("| --- | ---: | ---: | ---: |")
    for r in sorted([x for x in exact if x[1] + x[2] > 0], key=lambda r: r[3])[:15]:
        p(f"| {by_id[r[0]]['name']} | {r[1]} | {r[2]} | {r[3]:,} |")
    p()
    zero = [r for r in rows if r[1] + r[2] == 0]
    p(f"- {len(zero)} entries typed as weapons have no mod slots at all (signal "
      "cartridges, launchers): one configuration each, listed in `weapon_build_stats`.")
    p()

    # ---- wiki builds vs preset part lists --------------------------------
    variants = []
    vpath = os.path.join(C.CANON, "weapon_variants.ndjson")
    if os.path.exists(vpath):
        variants = list(C.load_jsonl(vpath))
    by_id = {i["bsg_id"]: i for i in items}
    subset = matched = 0
    extras = []
    for v in variants:
        pid = v.get("preset_bsg_id")
        if not pid or pid not in by_id:
            continue
        matched += 1
        wiki = {a["bsg_id"] for a in v["attachments"]}
        api = {c["bsg_id"] for c in by_id[pid]["contains_items"]}
        if wiki <= api:
            subset += 1
        extras.append(len(api - wiki))
    p("## Wiki build vs preset part list")
    p()
    if matched:
        p(f"- wiki builds matched to a preset: **{matched}**")
        p(f"- wiki attachment list is a subset of the preset's contained items: **{subset}**")
        p(f"- API-only parts per build: {dict(sorted(Counter(extras).items()))} — the preset")
        p("  list additionally carries the base weapon itself and a loaded magazine,")
        p("  which the wiki's attachment table does not list.")
    else:
        p("- no matched builds to compare")
    p()

    p("## Required slots no item can fill")
    p()
    if unfillable:
        seen = sorted({(by_id[i]["name"], s) for i, s in unfillable if i in by_id})
        for name, s in seen[:25]:
            p(f"- `{name}` → slot `{s}`")
        p(f"- total: {len(seen)} distinct (weapon, slot) pairs")
    else:
        p("- none: every required slot has at least one item that exists in the dataset.")
    p()

    os.makedirs(C.REPORTS, exist_ok=True)
    with open(os.path.join(C.REPORTS, "07_weapon_builds.md"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(L) + "\n")
    print("\n".join(L))
    print(f"\n[wrote reports/07_weapon_builds.md, {len(L)} lines]")


if __name__ == "__main__":
    main()
