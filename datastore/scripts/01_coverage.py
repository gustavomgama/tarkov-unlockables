#!/usr/bin/env python3
"""Cross-source coverage + integrity analysis.

Answers: which BSG item ids exist in which source, how many have no
resolvable display name, and whether every cross-reference resolves.

Writes: datastore/reports/01_coverage.md
Run: ~/.pyvenv-tarkov/bin/python datastore/scripts/01_coverage.py
"""
from __future__ import annotations

import json
import os
import re
from collections import Counter, defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
DS = os.path.abspath(os.path.join(HERE, ".."))
ROOT = os.path.abspath(os.path.join(DS, "..", "offlinedata"))
L = []


def p(*a):
    line = " ".join(str(x) for x in a)
    L.append(line)
    print(line)


def load(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8") as fh:
        return json.load(fh)


def pct(n, d):
    return f"{n} ({n * 100 // d if d else 0}%)"


def main():
    tdev = load("tarkovdev/items.json")["data"]
    tdev_items = tdev["items"]
    tdev_tasks = load("tarkovdev/tasks.json")["data"]
    tasks = tdev_tasks["tasks"]
    quest_items = tdev_tasks["questItems"]
    achieves = tdev_tasks["achievements"]
    barters = load("tarkovdev/barters.json")["data"]
    crafts = load("tarkovdev/crafts.json")["data"]
    traders = load("tarkovdev/traders.json")["data"]

    index_items = load("tarkovunlockables/items_index.json")
    wiki_items = load("officialwiki/parsed_items.json")
    market_items = load("tarkovmarket/items_all.json")
    market_item_example = load("tarkovmarket/item.json")
    wiki_barters = load("officialwiki/barter_list.json")
    wiki_crafts = load("officialwiki/craft_list.json")

    ids_index = {i["bsg_id"] for i in index_items if i.get("bsg_id")}
    ids_wiki = set(wiki_items)
    ids_market = {m["bsgId"] for m in market_items if m.get("bsgId")}
    ids_tdev = set(tdev_items)
    ids_quest = set(quest_items)
    ids_special = set(tdev.get("specialItems") or [])

    sources = {
        "tarkovdev/items": ids_tdev,
        "tarkovunlockables/items_index": ids_index,
        "officialwiki/parsed_items": ids_wiki,
        "tarkovmarket/items_all": ids_market,
    }
    universe = set().union(*sources.values()) | ids_quest | ids_special

    p("# Coverage & Integrity Report")
    p()
    p(f"Universe of distinct BSG ids across all item sources: **{len(universe)}**")
    p()
    p("## Source sizes")
    p()
    p("| source | ids | share of universe |")
    p("| --- | ---: | ---: |")
    for name, s in sources.items():
        p(f"| {name} | {len(s)} | {pct(len(s), len(universe))} |")
    p(f"| tarkovdev questItems (separate dict) | {len(ids_quest)} | {pct(len(ids_quest), len(universe))} |")
    p(f"| tarkovdev specialItems | {len(ids_special)} | {pct(len(ids_special), len(universe))} |")
    p()

    p("## Pairwise overlap (intersection counts)")
    p()
    names = list(sources)
    p("| A \\ B | " + " | ".join(n.split("/")[0] + "/" + n.split("/")[1][:12] for n in names) + " |")
    p("| --- |" + " ---: |" * len(names))
    for a in names:
        row = [a]
        for b in names:
            row.append(str(len(sources[a] & sources[b])))
        p("| " + " | ".join(row) + " |")
    p()

    p("## Exclusives / gaps")
    p()
    only_tdev = ids_tdev - ids_index - ids_wiki - ids_market
    only_index = ids_index - ids_tdev
    only_wiki = ids_wiki - ids_tdev
    only_market = ids_market - ids_tdev
    p(f"- tarkovdev items NOT in any other source: **{len(only_tdev)}**")
    p(f"- items_index ids missing from tarkovdev: **{len(only_index)}**")
    p(f"- wiki ids missing from tarkovdev: **{len(only_wiki)}**")
    p(f"- market ids missing from tarkovdev: **{len(only_market)}**")
    p(f"- items_index ids not in wiki: **{len(ids_index - ids_wiki)}**")
    p(f"- wiki ids not in items_index: **{len(ids_wiki - ids_index)}**")
    p()

    tdev_types = {i: (tdev_items[i].get("types") or []) for i in only_tdev}
    tc = Counter(t for ts in tdev_types.values() for t in ts)
    pc = Counter(((tdev_items.get(i) or {}).get("properties") or {}).get("propertiesType", "?") for i in only_tdev)
    p(f"  - by tarkovdev `types`: {tc.most_common(12)}")
    p(f"  - by propertiesType: {pc.most_common(12)}")
    p()

    p("## Display-name resolution (tarkovdev names are placeholders)")
    p()
    index_name = {i["bsg_id"]: i for i in index_items if i.get("bsg_id")}
    market_name = {m["bsgId"]: m for m in market_items if m.get("bsgId")}
    resolved = {"wiki": 0, "market": 0, "index": 0, "none": 0}
    unresolved = []
    for i in universe:
        if i in ids_wiki and wiki_items[i].get("full_name"):
            resolved["wiki"] += 1
        elif i in market_name and market_name[i].get("name"):
            resolved["market"] += 1
        elif i in index_name and index_name[i].get("full_name"):
            resolved["index"] += 1
        else:
            resolved["none"] += 1
            unresolved.append(i)
    p(f"- full_name from officialwiki: **{resolved['wiki']}**")
    p(f"- else from tarkovmarket: **{resolved['market']}**")
    p(f"- else from items_index: **{resolved['index']}**")
    p(f"- **no display name anywhere: {resolved['none']}**")
    p()
    if unresolved:
        p("### Unresolved items (id / normalizedName / types)")
        p()
        for i in sorted(unresolved)[:60]:
            r = tdev_items.get(i, {})
            p(f"- `{i}` — `{r.get('normalizedName','?')}` — types={r.get('types')}")
        if len(unresolved) > 60:
            p(f"- … and {len(unresolved) - 60} more")
        p()

    p("## Trade & task cross-reference integrity")
    p()
    trader_ids = set(traders)
    unknown_barter_traders = {b["trader"] for b in barters if b["trader"] not in trader_ids}
    unknown_task_traders = {t["trader"] for t in tasks.values() if t["trader"] not in trader_ids}
    p(f"- traders defined: {len(trader_ids)}")
    p(f"- barter.trader values not in traders: {sorted(unknown_barter_traders)}")
    p(f"- task.trader values not in traders: {sorted(unknown_task_traders)}")
    p(f"- barter offeredItem ids not in tarkovdev items: {len({b['offeredItem']['item'] for b in barters if b['offeredItem'] and b['offeredItem'].get('item') not in ids_tdev})}")
    p(f"- barter requiredItems ids not in tarkovdev items: {len({ri['item'] for b in barters for ri in b['requiredItems'] if ri.get('item') not in ids_tdev})}")
    p(f"- craft requiredItems ids not in tarkovdev items: {len({ri['item'] for c in crafts for ri in c['requiredItems'] if ri.get('item') not in ids_tdev})}")
    p(f"- craft productItem ids not in tarkovdev items: {len({c['productItem']['item'] for c in crafts if c['productItem'].get('item') not in ids_tdev})}")
    stations = {c["station"] for c in crafts}
    p(f"- distinct craft.station ids: {len(stations)}")
    for s in stations:
        p(f"    - `{s}` in tarkovdev items? {s in tdev_items}  name={tdev_items.get(s,{}).get('normalizedName')}")
    maps = {t["map"] for t in tasks.values() if t.get("map")}
    p(f"- distinct task.map ids: {len(maps)}")
    for m in sorted(maps):
        p(f"    - `{m}` in tarkovdev items? {m in tdev_items}  normalizedName={tdev_items.get(m,{}).get('normalizedName')}")
    p()

    p("## Objective type census (task objectives)")
    p()
    oc = Counter(o.get("type") for t in tasks.values() for o in (t.get("objectives") or []))
    for k, v in oc.most_common():
        p(f"- {k}: {v}")
    p()

    p("## Reward block census")
    p()
    start_keys = Counter()
    fin_keys = Counter()
    for t in tasks.values():
        start_keys.update((t.get("startRewards") or {}).keys())
        fin_keys.update((t.get("finishRewards") or {}).keys())
    p(f"- startRewards keys: {dict(start_keys)}")
    p(f"- finishRewards keys: {dict(fin_keys)}")
    p()

    p("## Reference-only datasets")
    p()
    p(f"- questItems: {len(quest_items)} (ids not all in items dict: {len(ids_quest - ids_tdev)})")
    p(f"- achievements: {len(achieves)}")
    p(f"- wiki barter_list rows: {len(wiki_barters)}; wiki craft stations: {len(wiki_crafts)}")
    p(f"- tarkovmarket single-item example carries price fields: {sorted(k for k in market_item_example[0] if 'rice' in k or k in ('bannedOnFlea','haveMarketData','updated','slots','traderName','traderPriceRub','isFunctional'))}")
    p()

    cross_source(index_items, wiki_items, market_items, barters, crafts, wiki_barters)

    os.makedirs(os.path.join(DS, "reports"), exist_ok=True)
    with open(os.path.join(DS, "reports/01_coverage.md"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(L) + "\n")
    print(f"\n[wrote reports/01_coverage.md, {len(L)} lines]")


def cross_source(index_items, wiki_items, market_items, barters, crafts, wiki_barters):
    """Cross-source agreement checks, run before canonical exists."""

    p("## Cross-source agreement")
    p()

    # 1. tarkovdev barter/craft coverage vs the derived unlockables index
    barter_offered = {b["offeredItem"]["item"] for b in barters if b.get("offeredItem")}
    craft_products = {c["productItem"]["item"] for c in crafts if c.get("productItem")}
    buy_items = {b["trader"] for b in barters}
    idx_barter = {i["bsg_id"] for i in index_items if any(o.get("barter") for o in (i.get("obtain_from") or []))}
    idx_craft = {i["bsg_id"] for i in index_items if any(o.get("hideout") for o in (i.get("obtain_from") or []))}
    idx_buy = {i["bsg_id"] for i in index_items if any(o.get("currency") for o in (i.get("obtain_from") or []))}
    p(f"- items the index calls **barterable**: {len(idx_barter)}; tarkovdev barters cover {len(idx_barter & barter_offered)} "
      f"(missing {len(idx_barter - barter_offered)})")
    p(f"- items the index calls **craftable**: {len(idx_craft)}; tarkovdev crafts cover {len(idx_craft & craft_products)} "
      f"(missing {len(idx_craft - craft_products)})")
    p(f"- items the index calls **currency-buyable**: {len(idx_buy)} "
      f"(per-trader rows in tarkovdev, so exact overlap is not comparable)")
    p(f"- tarkovdev barters offer {len(barter_offered - idx_barter)} items the index does not mark as barterable "
      "(newer offers than the index)")
    p(f"- tarkovdev crafts produce {len(craft_products - idx_craft)} items the index does not mark as craftable")
    p()

    # 2. wiki barter_list (names, no ids) vs tarkovdev barter count
    p(f"- wiki barter_list rows (names only): {len(wiki_barters)} vs tarkovdev barters: {len(barters)} "
      f"— the wiki lags the live API")
    p()

    # 3. craft station id -> name mapping sanity (crafts per station id vs wiki per station name)
    counts_id = Counter(c["station"] for c in crafts)
    p(f"- distinct craft station ids: {len(counts_id)}; craft counts per id: {sorted(counts_id.values(), reverse=True)}")
    p()

    # 4. tarkovmarket duplicates + bsgId coverage
    seen = Counter(m["bsgId"] for m in market_items if m.get("bsgId"))
    dups = {k: v for k, v in seen.items() if v > 1}
    p(f"- tarkovmarket records: {len(market_items)}; distinct bsgId: {len(seen)}; duplicate ids: {len(dups)} "
      f"e.g. {list(dups.items())[:3]}")
    p()

    # 5. the documented wiki gap list
    gap_path = os.path.join(ROOT, "officialwiki/wiki_items_not_in_items_index.wiki")
    if os.path.exists(gap_path):
        with open(gap_path, encoding="utf-8") as fh:
            gaps = re.findall(r"^== ([0-9a-f]{24}) ==", fh.read(), re.M)
        ids_tdev = set()
        p(f"- `wiki_items_not_in_items_index.wiki` lists {len(gaps)} ids absent from the derived index")
    p()


if __name__ == "__main__":
    main()
