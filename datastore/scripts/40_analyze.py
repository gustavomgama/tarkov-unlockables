#!/usr/bin/env python3
"""Graph and progression analysis over the canonical dataset.

Reads `canonical/tasks.ndjson` (whose `graph` block was annotated during the
build) plus traders/maps, checks the quest graph is a well-formed DAG, and
writes `reports/05_task_graph.md` with the progression shape: depths, the
Kappa / Lightkeeper prerequisite closures, XP totals and level gates.

Run: ~/.pyvenv-tarkov/bin/python datastore/scripts/40_analyze.py
"""
from __future__ import annotations

import os
from collections import Counter, defaultdict
from functools import lru_cache

import _common as C

L = []


def p(*a):
    line = " ".join(str(x) for x in a)
    L.append(line)


def main():
    tasks = list(C.load_jsonl(os.path.join(C.CANON, "tasks.ndjson")))
    traders = {t["slug"]: t for t in C.load_jsonl(os.path.join(C.CANON, "traders.ndjson"))}
    maps = {m["id"]: m for m in C.load_jsonl(os.path.join(C.CANON, "maps.ndjson"))}
    ids = {t["id"] for t in tasks}
    by = {t["id"]: t for t in tasks}

    prereq = {t["id"]: {x["bsg_id"] for x in t["task_requirements"] if x.get("bsg_id") in ids}
              | {x for x in t["previous_tasks"] if x in ids} for t in tasks}
    forward = {(t["id"], x["task_id"]) for t in tasks for x in t["leads_to"] if x["task_id"] in ids}

    # --- integrity -------------------------------------------------------
    unmirrored = sorted((a, b) for a, b in forward if a not in prereq[b])
    orphans = sorted(x for t in tasks for x in prereq[t["id"]] if x not in ids)

    color = {}

    def dfs(u, path):
        color[u] = 1
        for v in prereq[u]:
            if color.get(v, 0) == 1:
                return path + [u, v]
            if color.get(v, 0) == 0:
                hit = dfs(v, path + [u])
                if hit:
                    return hit
        color[u] = 2
        return None

    cycle = None
    for tid in ids:
        if color.get(tid, 0) == 0:
            cycle = dfs(tid, [])
            if cycle:
                break

    p("# Task graph analysis")
    p()
    p(f"- tasks: **{len(tasks)}**")
    p(f"- prerequisite edges: **{sum(len(v) for v in prereq.values())}** (from `task_requirements` + `previous_tasks`)")
    p(f"- forward edges (`leads_to`): **{len(forward)}**")
    p(f"- cycles: **{'none' if not cycle else ' → '.join(cycle)}**")
    p(f"- prerequisite ids outside the dataset: **{len(orphans)}**")
    p(f"- forward edges whose prerequisite is not recorded on the target: **{len(unmirrored)}**")
    for a, b in unmirrored:
        p(f"    - `{by[a]['name']}` → `{by[b]['name']}` (target lists no prerequisite)")
    p()

    # --- depth -----------------------------------------------------------
    depths = Counter(t["graph"]["depth"] for t in tasks)
    p("## Prerequisite depth (longest chain to reach the task)")
    p()
    p(f"- max depth: **{max(depths)}**")
    p(f"- depth distribution: {dict(sorted(depths.items()))}")
    deepest = max(tasks, key=lambda t: t["graph"]["depth"])
    path, cur = [], deepest["id"]
    while cur:
        path.append(by[cur]["name"])
        nxt = sorted(prereq[cur], key=lambda x: -by[x]["graph"]["depth"])
        cur = nxt[0] if nxt else None
    p(f"- longest chain ({len(path)}): " + " → ".join(reversed(path)))
    p()

    # --- closures --------------------------------------------------------
    def closure(seed):
        seen, stack = set(), list(seed)
        while stack:
            for v in prereq[stack.pop()]:
                if v not in seen:
                    seen.add(v)
                    stack.append(v)
        return seen

    p("## Endgame requirements")
    p()
    for label, flag in (("Kappa", "kappa_required"), ("Lightkeeper", "lightkeeper_required")):
        flagged = {t["id"] for t in tasks if t[flag]}
        chain = flagged | closure(flagged)
        xp = sum(by[i]["experience"] or 0 for i in chain)
        level = max((by[i]["min_player_level"] or 0 for i in chain), default=0)
        p(f"### {label}")
        p()
        p(f"- flagged tasks: **{len(flagged)}**; with prerequisite closure: **{len(chain)}**")
        p(f"- total XP from the chain: **{xp:,}**; highest character-level gate: **{level}**")
        p(f"- traders involved: {dict(sorted(Counter(by[i]['trader_slug'] for i in chain).items(), key=lambda kv: (-kv[1], kv[0])))}")
        roots = [by[i]["name"] for i in chain if not (prereq[i] & chain)]
        p(f"- chain starts at: {', '.join(f'`{r}`' for r in sorted(roots))}")
        p()

    # --- workload --------------------------------------------------------
    p("## Workload distribution")
    p()
    per_trader = Counter(t["trader_slug"] for t in tasks)
    p("| trader | tasks | min level range | kappa chain |")
    p("| --- | ---: | --- | ---: |")
    for slug, n in per_trader.most_common():
        lv = [t["min_player_level"] or 0 for t in tasks if t["trader_slug"] == slug]
        kappa = sum(1 for t in tasks if t["trader_slug"] == slug and t["graph"]["kappa_chain"])
        p(f"| {traders.get(slug, {}).get('name', slug)} | {n} | {min(lv)}–{max(lv)} | {kappa} |")
    p()
    p(f"- tasks with no map: **{sum(1 for t in tasks if not t['map_id'])}**")
    p(f"- maps used: **{len({t['map_id'] for t in tasks if t['map_id']})}** of {len(maps)}")
    per_map = Counter(t["map_name"] for t in tasks if t["map_name"])
    p("- tasks per map: " + ", ".join(f"{m} {n}" for m, n in per_map.most_common()))
    p()
    levels = Counter(t["min_player_level"] or 0 for t in tasks)
    p(f"- character-level gates: {dict(sorted(levels.items()))}")
    factions = Counter(t["faction"] for t in tasks)
    p(f"- factions: {dict(factions)}")
    p()

    os.makedirs(C.REPORTS, exist_ok=True)
    with open(os.path.join(C.REPORTS, "05_task_graph.md"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(L) + "\n")
    print("\n".join(L))
    print(f"\n[wrote reports/05_task_graph.md, {len(L)} lines]")


if __name__ == "__main__":
    main()
