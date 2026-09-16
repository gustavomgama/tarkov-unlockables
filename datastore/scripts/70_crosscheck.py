#!/usr/bin/env python3
"""Cross-check the community wiki's trade and craft lists against the dataset.

`officialwiki/barter_list.json` (443 trades) and `craft_list.json` (8 stations)
are parsed from the wiki's "List of Trades" / "List of crafts" tables. They are
name-only, so matching is by (normalized trader, normalized item name).

The wiki's trade table mixes currency purchases and barter offers, so a trade is
counted as matched if the (trader, item) pair appears in **any** canonical route
for that item: a barter offer, a tarkovdev purchase, or an index purchase claim.
Residuals are listed rather than hidden — the wiki lags the live API, so the
tdev-only direction is expected to be large and the wiki-only direction is the
interesting one.

Writes `reports/08_wiki_crosscheck.md`.

Run: ~/.pyvenv-tarkov/bin/python datastore/scripts/70_crosscheck.py
"""
from __future__ import annotations

import os
import re
from collections import defaultdict

import _common as C

L = []


def p(*a):
    L.append(" ".join(str(x) for x in a))


def norm(text):
    return re.sub(r"[^a-z0-9]+", "", (text or "").lower())


def wiki_number(value):
    """The wiki's infobox numbers carry signs, percent signs and units
    ("+61.5", "10%", "770 m/s") -> float, or None when absent/not numeric."""
    if value is None:
        return None
    cleaned = re.sub(r"[^0-9.\-+%]", "", str(value)).replace("%", "")
    try:
        return float(cleaned)
    except ValueError:
        return None


# wiki infobox key <-> tarkovdev property, in the wiki's own units:
# the API stores accuracy/recoil as fractions (-0.05 = -5%) and
# durability/heat as 1+factor (1.15 = +15"), and the wiki rounds those to one
# decimal, hence the 0.11 tolerance.
BALLISTICS = [
    ("damage", "damage", lambda a: a, 0.05),
    ("penetration", "penetrationPower", lambda a: a, 0.05),
    ("armor_damage", "armorDamage", lambda a: a, 0.05),
    ("velocity", "initialSpeed", lambda a: a, 0.05),
    ("ricochet", "ricochetChance", lambda a: a * 100, 0.11),
    ("accuracy", "accuracyModifier", lambda a: a * 100, 0.11),
    ("recoil", "recoilModifier", lambda a: a * 100, 0.11),
    ("durability_burn", "durabilityBurnFactor", lambda a: (a - 1) * 100, 0.11),
    ("heat", "heatFactor", lambda a: (a - 1) * 100, 0.11),
]


def ammo_ballistics(items):
    """Compare wiki infobox ballistics against the API's ammo properties.

    Both sources carry the same numbers in different units, so this is the one
    place the dataset gets a *numeric* cross-check rather than a name/count one.
    """
    ammo = [i for i in items
            if i["properties_type"] == "ItemPropertiesAmmo" and i.get("wiki")]
    compared = agreed = 0
    per_field = []
    disagreements = []
    for wiki_key, api_key, scale, tol in BALLISTICS:
        field_compared = field_agreed = 0
        for i in ammo:
            w = wiki_number((i["wiki"]["infobox"] or {}).get(wiki_key))
            a = i["properties"].get(api_key)
            if w is None or a is None:
                continue
            field_compared += 1
            if abs(w - scale(a)) <= tol:
                field_agreed += 1
            else:
                disagreements.append({
                    "item": i["name"], "bsg_id": i["bsg_id"], "field": wiki_key,
                    "wiki": str((i["wiki"]["infobox"] or {}).get(wiki_key)), "api": a,
                })
        compared += field_compared
        agreed += field_agreed
        per_field.append((wiki_key, field_compared, field_agreed))
    return compared, agreed, per_field, disagreements


def main():
    items = list(C.load_jsonl(os.path.join(C.CANON, "items.ndjson")))
    barters = list(C.load_jsonl(os.path.join(C.CANON, "barters.ndjson")))
    crafts = list(C.load_jsonl(os.path.join(C.CANON, "crafts.ndjson")))

    names = defaultdict(list)
    for i in items:
        names[norm(i["name"])].append(i["bsg_id"])

    barter_pairs = {(b["trader_slug"], norm((b["offered_item"] or {}).get("name"))) for b in barters}
    trade_pairs = set(barter_pairs)
    for i in items:
        n = norm(i["name"])
        trade_pairs |= {(o["trader_slug"], n) for o in i["acquisition"]["buy"]}
        trade_pairs |= {(o["trader_slug"], n) for o in i["acquisition"]["index_offers"]}

    wiki_barters = C.load_off("officialwiki/barter_list.json")
    wiki_pairs, display, total, matched = set(), {}, 0, 0
    for w in wiki_barters:
        trader = norm(w["trader_name"])
        for r in w["result_items"]:
            total += 1
            pair = (trader, norm(r["name"]))
            wiki_pairs.add(pair)
            display.setdefault(pair, (w["trader_name"], r["name"]))
            if pair in trade_pairs:
                matched += 1

    craft_pairs = {(norm(c["station_name"]), norm((c["product_item"] or {}).get("name"))) for c in crafts}
    wiki_crafts = C.load_off("officialwiki/craft_list.json")
    c_total = c_matched = 0
    wiki_craft_pairs = set()
    for station, rows in wiki_crafts.items():
        for r in rows:
            for o in r["output_items"]:
                c_total += 1
                pair = (norm(station), norm(o["name"]))
                wiki_craft_pairs.add(pair)
                display.setdefault(("craft",) + pair, (station, o["name"]))
                if pair in craft_pairs:
                    c_matched += 1

    unresolved_names = sorted({display[("craft",) + pair][1] if ("craft",) + pair in display else display[pair][1]
                               for pair in (wiki_pairs - trade_pairs) | (wiki_craft_pairs - craft_pairs)
                               if pair[1] not in names})
    b_only = sorted(wiki_pairs - trade_pairs)
    c_only = sorted(wiki_craft_pairs - craft_pairs)

    p("# Wiki cross-check")
    p()
    p("The wiki's trade and craft tables are name-only and lag the live API, so")
    p("they are used as corroboration, not as a source.")
    p()
    p("## Trades")
    p()
    p(f"- wiki rows: **{total}**")
    p(f"- matched to a canonical route (barter, tdev purchase or index claim): "
      f"**{matched}** ({matched * 100 // total}%)")
    p(f"- wiki-only pairs: **{len(b_only)}** (trades the wiki lists that no canonical route ")
    p(f"  covers — usually renamed or removed content)")
    p(f"- canonical (trader, item) pairs: **{len(trade_pairs)}** — the wiki table covers a")
    p("  small, older slice of them, which is the expected direction of drift")
    p(f"- wiki item names absent from the dataset entirely: **{len(unresolved_names)}**")
    p()
    if b_only[:40]:
        p("### Wiki-only trades (first 40)")
        p()
        for pair in b_only[:40]:
            trader, item = display.get(pair, pair)
            p(f"- {trader} → {item}")
        p()
    p("## Ammo ballistics")
    p()
    b_total, b_agree, b_fields, b_diffs = ammo_ballistics(items)
    p(f"- ammo types with both a wiki infobox and API properties: **{len([i for i in items if i['properties_type'] == 'ItemPropertiesAmmo' and i.get('wiki')])}**")
    p(f"- field values compared: **{b_total}**; equal after unit conversion and the")
    p(f"  wiki's 1-decimal rounding: **{b_agree}** ({b_agree * 100 // max(b_total, 1)}%)")
    p()
    p("| field | compared | equal |")
    p("| --- | ---: | ---: |")
    for key, c, a in b_fields:
        p(f"| {key} | {c} | {a} |")
    p()
    if b_diffs:
        p("### Substantive disagreements")
        p()
        p("| item | field | wiki | api |")
        p("| --- | --- | ---: | ---: |")
        for d in b_diffs:
            p(f"| {d['item']} | {d['field']} | {d['wiki']} | {d['api']} |")
        p()

    p("## Crafts")
    p()
    p(f"- wiki outputs: **{c_total}**")
    p(f"- matched by (station, product): **{c_matched}** ({c_matched * 100 // max(c_total, 1)}%)")
    p(f"- wiki-only crafts: **{len(c_only)}**")
    p()
    if c_only:
        p("### Wiki-only crafts")
        p()
        for pair in c_only:
            station, item = display.get(("craft",) + pair, pair)
            p(f"- {station} → {item}")
        p()
    if unresolved_names:
        p("### Wiki names with no dataset item")
        p()
        for n in unresolved_names[:40]:
            p(f"- `{n}`")
        p()

    summary = {
        "wiki_trades": total,
        "trades_matched": matched,
        "wiki_only_trades": len(b_only),
        "canonical_trade_pairs": len(trade_pairs),
        "wiki_crafts": c_total,
        "crafts_matched": c_matched,
        "wiki_only_crafts": len(c_only),
        "unresolved_wiki_names": len(unresolved_names),
        "ballistics_compared": b_total,
        "ballistics_agreed": b_agree,
        "ballistics_disagreements": len(b_diffs),
    }
    os.makedirs(C.REPORTS, exist_ok=True)
    with open(os.path.join(C.REPORTS, "08_wiki_crosscheck.md"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(L) + "\n")
    import json as _json
    with open(os.path.join(C.REPORTS, "08_wiki_crosscheck.json"), "w", encoding="utf-8") as fh:
        _json.dump(summary, fh, indent=2, sort_keys=True)
    print("\n".join(L[:20]))
    print(f"\n[wrote reports/08_wiki_crosscheck.md, {len(L)} lines]")


if __name__ == "__main__":
    main()
