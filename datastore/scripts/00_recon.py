#!/usr/bin/env python3
"""Reconnaissance: dump the shape of every offlinedata source.

Read-only. Prints a structural report; writes nothing.
Run: ~/.pyvenv-tarkov/bin/python datastore/scripts/00_recon.py
"""
from __future__ import annotations

import json
import os
import _common as C
from collections import Counter

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "offlinedata")
OUT = []


def p(*a):
    line = " ".join(str(x) for x in a)
    OUT.append(line)
    print(line)


def load(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8") as fh:
        return json.load(fh)


def key_census(records):
    keys, types = Counter(), {}
    for r in records:
        if not isinstance(r, dict):
            continue
        for k, v in r.items():
            keys[k] += 1
            if k not in types:
                types[k] = f"{type(v).__name__}({len(v)})" if isinstance(v, (list, dict)) else type(v).__name__
    return keys, types


def show_shape(name, records, limit=None):
    records = list(records)
    if limit:
        records = records[:limit]
    keys, types = key_census(records)
    n = len(records)
    p(f"\n### {name}  ({n} records)")
    for k, c in keys.most_common():
        p(f"    {k:<36} {types[k]:<18} {c}/{n}")


def j(v, maxlen=200):
    s = json.dumps(v, ensure_ascii=False)
    return s if len(s) <= maxlen else s[:maxlen] + "…"


def sample(rec, keys=None, maxlen=200):
    if not isinstance(rec, dict):
        return j(rec, maxlen)
    items = [(k, v) for k, v in rec.items() if not keys or k in keys]
    return "\n".join(f"    {k} = {j(v, maxlen)}" for k, v in items)


def crossref(label, items, key):
    vals = []
    for i in items:
        if not isinstance(i, dict):
            continue
        v = i.get(key)
        if isinstance(v, list):
            vals.extend(x if not isinstance(x, (dict, list)) else json.dumps(x)[:40] for x in v)
        elif isinstance(v, dict):
            vals.append(v.get("id") or v.get("name") or json.dumps(v)[:40])
        elif v is not None:
            vals.append(v)
    c = Counter(vals)
    p(f"  {label}.{key}: {len(c)} distinct, top {c.most_common(8)}")


def main():
    D = "tarkovdev/"

    ti = load(D + "items.json")["data"]
    p("=" * 90)
    p("TARKOVDEV /items  data keys:", list(ti))
    p("=" * 90)
    for k, v in ti.items():
        p(f"  data[{k}]: {type(v).__name__} len={len(v) if hasattr(v,'__len__') else v}")
    items = list(ti["items"].values())
    p(f"\nitems: {len(items)}  id sample={list(ti['items'])[:2]}")
    show_shape("item", items)
    p("\n--- sample item ---")
    p(sample(items[0], maxlen=120))
    p("\n--- itemCategories sample ---")
    p(sample(list(ti["itemCategories"].values())[0], maxlen=120))
    p("--- handbookCategories sample ---")
    p(sample(list(ti["handbookCategories"].values())[0], maxlen=120))
    p("\n--- fleaMarket / armorMaterials / playerLevels / settings ---")
    for k in ("fleaMarket", "armorMaterials", "playerLevels", "mastering", "skills", "specialItems", "settings"):
        v = ti.get(k)
        p(f"  {k}: {type(v).__name__} len={len(v) if hasattr(v,'__len__') else v}")
        if isinstance(v, dict) and v:
            fk = list(v)[0]
            p(f"      [{fk}] = {j(v[fk], 200)}")
        elif isinstance(v, list) and v:
            p(f"      [0] = {j(v[0], 200)}")

    tks = load(D + "tasks.json")["data"]
    p("\n" + "=" * 90)
    p("TARKOVDEV /tasks  data keys:", list(tks))
    p("=" * 90)
    for k, v in tks.items():
        p(f"  data[{k}]: {type(v).__name__} len={len(v) if hasattr(v,'__len__') else v}")
    tasks = list(tks["tasks"].values())
    show_shape("task", tasks)
    p("\n--- sample task ---")
    p(sample(tasks[0], maxlen=150))
    p("\n--- questItems sample ---")
    p(sample(list(tks["questItems"].values())[0], maxlen=150))
    p("--- achievements sample ---")
    p(sample(list(tks["achievements"].values())[0], maxlen=150))
    p("--- prestige ---")
    p("    " + j(tks.get("prestige"), 200))

    barters = load(D + "barters.json")["data"]
    show_shape("barter", barters)
    p("\n--- sample barter ---")
    p(sample(barters[0], maxlen=250))

    crafts = load(D + "crafts.json")["data"]
    show_shape("craft", crafts)
    p("\n--- sample craft ---")
    p(sample(crafts[0], maxlen=250))

    trs = load(D + "traders.json")["data"]
    p(f"\n--- traders: {len(trs)} keyed by raw id ---")
    show_shape("trader", list(trs.values()))
    p("\n--- sample trader ---")
    p(sample(list(trs.values())[0], maxlen=150))
    p("  traders name/normalizedName:")
    for k, v in trs.items():
        p(f"    {k}  name={j(v.get('name'))}  normalized={j(v.get('normalizedName'))}")

    p("\n" + "=" * 90)
    p("TARKOVDEV cross-refs")
    p("=" * 90)
    crossref("barter", barters, "trader")
    crossref("craft", crafts, "station")
    crossref("task", tasks, "trader")
    p("  item.types census:", Counter(t for i in items for t in (i.get("types") or [])).most_common())
    p("  item.categories sample:", j(items[0].get("categories")))

    tm = load("tarkovmarket/items_all.json")
    show_shape("tarkovmarket item", tm)
    p("\n--- sample ---")
    p(sample(tm[0], ["uid", "bsgId", "name", "tags", "price", "avg24hPrice", "basePrice",
                      "traderName", "traderPriceRub", "bannedOnFlea", "haveMarketData", "slots", "updated"]))
    p("\n  tags census top 30:", Counter(t for it in tm for t in it.get("tags", [])).most_common(30))

    for f in ["items_index.json", "tasks_index.json", "traders_index.json", "buyables_index.json",
              "barteables_index.json", "craftables_index.json", "task_gated_buyables.json",
              "task_gated_barters.json", "task_gated_crafts.json"]:
        d = load("tarkovunlockables/" + f)
        if isinstance(d, list):
            show_shape(f, d, limit=400)
            p("    sample:", j(d[0], 300))
        else:
            p(f"\n### {f}  DICT {len(d)} keys={list(d)[:6]}")
            vals = list(d.values())
            if vals and isinstance(vals[0], list):
                p(f"    values are lists, first(len={len(vals[0])}): {j(vals[0][:2], 300)}")
            elif vals and isinstance(vals[0], dict):
                show_shape(f + " (values)", vals, limit=400)

    pi = load("officialwiki/parsed_items.json")
    p(f"\n### officialwiki/parsed_items.json  DICT keyed by id, {len(pi)} entries")
    show_shape("wiki parsed item", list(pi.values()), limit=2000)
    k0 = list(pi)[0]
    p(f"--- sample key={k0} ---")
    p(sample(pi[k0], maxlen=150))

    bl = load("officialwiki/barter_list.json")
    show_shape("wiki barter_list", bl)
    p("--- sample ---")
    p(sample(bl[0], maxlen=150))

    cl = load("officialwiki/craft_list.json")
    p(f"\n### officialwiki/craft_list.json stations={list(cl)}")
    st0 = list(cl)[0]
    show_shape(f"craft_list[{st0}]", cl[st0])
    p("--- sample ---")
    p(sample(cl[st0][0], maxlen=150))


if __name__ == "__main__":
    main()
    os.makedirs(C.REPORTS, exist_ok=True)
    with open(os.path.join(C.REPORTS, "00_recon.md"), "w", encoding="utf-8") as fh:
        fh.write("# Reconnaissance\n\n```\n" + "\n".join(OUT) + "\n```\n")
    print(f"\n[wrote reports/00_recon.md, {len(OUT)} lines]")
