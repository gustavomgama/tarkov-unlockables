#!/usr/bin/env python3
"""Route economics: what does each acquisition route actually cost?

Prices every barter and craft recipe with the snapshot flea prices of its
inputs and writes `item_acquisition_cost` into `tarkov.sqlite3`, plus
`reports/06_route_economics.md`.

Correctness rule: a route is only costed when **every** consumed input has a
price. Tools (`is_tool`) and quest items are not consumed and are excluded.
Routes with any unpriced input are recorded with `complete = 0` and a null
cost rather than being silently priced as if the missing inputs were free.

Run: ~/.pyvenv-tarkov/bin/python datastore/scripts/50_economics.py
"""
from __future__ import annotations

import os
import sqlite3

import _common as C

L = []


def p(*a):
    L.append(" ".join(str(x) for x in a))


def price_of(item):
    """Snapshot flea average, falling back to handbook base price."""
    econ = item["economy"]
    for key in ("avg24h_price", "last_low_price", "base_price"):
        v = econ.get(key)
        if v and v > 0:
            return v, key
    return None, None


def route_cost(routes, price, price_key):
    """Cheapest route with a complete price.

    Returns `(best, incompletes)` where best is `(cost, ref, route, inputs)`.
    A route with no consumable inputs (the Bitcoin farm's passive BTC craft)
    legitimately costs 0 and is still `complete`.
    """
    best = None
    incompletes = 0
    for r in routes:
        total, ok, inputs = 0, True, 0
        for ri in r["required"]:
            if ri.get("is_tool"):
                continue
            inputs += 1
            v = price.get(ri["bsg_id"])
            if v is None:
                ok = False
                break
            try:
                n = int(ri.get("count") or 1)
            except (TypeError, ValueError):
                n = 1
            total += v * max(n, 1)
        if not ok:
            incompletes += 1
            continue
        if best is None or total < best[0]:
            best = (total, r.get("barter_id") or r.get("craft_id"), r, inputs)
    return best, incompletes


def main():
    items = list(C.load_jsonl(os.path.join(C.CANON, "items.ndjson")))
    price, price_key = {}, {}
    for i in items:
        v, k = price_of(i)
        if v is not None:
            price[i["bsg_id"]] = v
            price_key[i["bsg_id"]] = k

    rows = []
    stats = {"barter_priced": 0, "barter_incomplete": 0, "craft_priced": 0, "craft_incomplete": 0}
    for i in items:
        bid = i["bsg_id"]
        for route, routes in (("barter", i["acquisition"]["barter"]), ("craft", i["acquisition"]["craft"])):
            if not routes:
                continue
            best, incompletes = route_cost(routes, price, price_key)
            stats[f"{route}_incomplete"] += incompletes
            if best:
                stats[f"{route}_priced"] += 1
                cost, ref, raw, inputs = best
                rows.append((bid, route, ref, cost, 1, len(routes) - incompletes, len(routes), inputs))
            else:
                rows.append((bid, route, None, None, 0, 0, len(routes), None))

    by_id = {i["bsg_id"]: i for i in items}
    con = sqlite3.connect(C.SQLITE)
    con.executescript("""
        DROP TABLE IF EXISTS item_acquisition_cost;
        CREATE TABLE item_acquisition_cost (
          bsg_id TEXT, route TEXT, ref_id TEXT, cost_rub INTEGER,
          complete INTEGER, priced_routes INTEGER, total_routes INTEGER,
          consumed_inputs INTEGER
        );
        CREATE INDEX idx_acq_cost_item ON item_acquisition_cost(bsg_id);
        CREATE INDEX idx_acq_cost_complete ON item_acquisition_cost(complete, cost_rub);
        DROP VIEW IF EXISTS v_item_acquisition_cost;
        CREATE VIEW v_item_acquisition_cost AS
        SELECT c.bsg_id, i.name, c.route, c.cost_rub, c.complete, c.priced_routes, c.total_routes,
               i.avg24h_price AS flea_price,
               CASE WHEN c.cost_rub IS NULL OR i.avg24h_price IS NULL THEN NULL
                    ELSE i.avg24h_price - c.cost_rub END AS vs_flea_rub
        FROM item_acquisition_cost c JOIN items i ON i.bsg_id = c.bsg_id;
    """)
    con.executemany("INSERT INTO item_acquisition_cost VALUES (?,?,?,?,?,?,?,?)", rows)

    # ---- report ---------------------------------------------------------
    priced = [r for r in rows if r[4]]
    p("# Route economics")
    p()
    p(f"- items with a barter or craft route: **{len({r[0] for r in rows})}**")
    p(f"- routes fully priced: **{stats['barter_priced']} barter**, **{stats['craft_priced']} craft**")
    p(f"- routes left uncosted because an input has no price: "
      f"**{stats['barter_incomplete']} barter**, **{stats['craft_incomplete']} craft**")
    p(f"- price source: flea `avg24h_price`, else `last_low_price`, else handbook `base_price`")
    zero = [r for r in rows if r[4] and r[3] == 0]
    p(f"- zero-cost routes: **{len(zero)}**" + (
        f" ({', '.join(by_id[r[0]]['name'] + ' — ' + r[1] for r in zero)}): recipes that consume no items at all"
        if zero else ""))
    p()

    def with_flea(route):
        out = []
        for r in priced:
            if r[1] != route:
                continue
            flea = by_id[r[0]]["economy"].get("avg24h_price")
            if flea:
                out.append((flea - r[3], r, flea))
        return out

    for route in ("barter", "craft"):
        rows_f = with_flea(route)
        cheaper = sorted([x for x in rows_f if x[0] > 0], key=lambda x: -x[0])
        p(f"## {route}: where the recipe beats the flea")
        p()
        if cheaper:
            p("| item | recipe cost | flea price | saving |")
            p("| --- | ---: | ---: | ---: |")
            for diff, r, flea in cheaper[:15]:
                p(f"| {by_id[r[0]]['name']} | {r[3]:,} ₽ | {flea:,} ₽ | {diff:,} ₽ |")
        else:
            p("No recipe is cheaper than the item's own flea price in this snapshot — "
              "as expected, recipes matter for `noFlea` items, not as flea arbitrage.")
        p()
        p(f"- {route} routes priced: {len(rows_f)}; cheaper than flea: **{len(cheaper)}**; "
          f"more expensive: {len(rows_f) - len(cheaper)}")
        noflea = [(r, flea) for diff, r, flea in rows_f if "noFlea" in by_id[r[0]]["types"]]
        p(f"- of those, on `noFlea` items (recipe is the only route): **{len(noflea)}**")
        p()

    p("## Most expensive recipes (input value)")
    p()
    p("| item | route | cost | inputs |")
    p("| --- | --- | ---: | ---: |")
    for r in sorted(priced, key=lambda r: -r[3])[:10]:
        p(f"| {by_id[r[0]]['name']} | {r[1]} | {r[3]:,} ₽ | {r[6]} |")
    p()
    con.commit()
    con.close()

    os.makedirs(C.REPORTS, exist_ok=True)
    with open(os.path.join(C.REPORTS, "06_route_economics.md"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(L) + "\n")
    print("\n".join(L))
    print(f"\n[wrote reports/06_route_economics.md, {len(L)} lines; {len(rows)} cost rows]")


if __name__ == "__main__":
    main()
