#!/usr/bin/env python3
"""Fetch and parse the wiki's Ballistics page into `canonical/`.

The page carries the one thing no tarkov.dev endpoint exposes: **how effective
each round is against each armor class** (the six `Bullet effectiveness`
columns) and the effectiveness scale those numbers are read on. Everything
else on the page repeats numbers the dataset already holds — the ammo
properties come from tarkov.dev, armor material destructibility from
`reference.json` — so those columns land as an explicit second copy that
`99_verify.py` pins value by value rather than trusting: 1,318 of them, at
least 95% must match, and both material numbers must.

Three quirks the parser handles:

* a damage cell shaped `9x35` is 9 projectiles x 35 damage each, so `damage`
  stays per-projectile (the API's unit) and `projectile_count` carries the
  multiplier;
* blanks are real (`accuracy` and the bleed columns are often empty) and an
  empty cell is not a zero;
* an `S`/`T` superscript on a name means subsonic/tracer.

The raw API response is cached under `fetched/` with a manifest entry so the
build stays reproducible offline. Pass --refresh to re-download.

Run: ~/.pyvenv-tarkov/bin/python datastore/scripts/25_ballistics.py [--refresh]
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import sys
import urllib.parse
import urllib.request
from datetime import datetime, timezone

import mwparserfromhell

import _common as C

TITLE = "Ballistics"
API = ("https://escapefromtarkov.fandom.com/api.php?format=json&action=query"
       "&titles={title}&prop=revisions&rvslots=*&rvprop=content&formatversion=2")
RAW = os.path.join(C.FETCHED, "ballistics.json")
MANIFEST = os.path.join(C.FETCHED, "manifest.json")
WIKI_BASE = "https://escapefromtarkov.fandom.com/wiki/"
# Fandom answers 403 to urllib's default user agent.
USER_AGENT = "tarkov-db datastore build (https://github.com/tarkov-db)"

# `9x35` in a damage cell: N projectiles of X damage each.
PELLETS = re.compile(r"^(\d+)\s*x\s*(\d+)$")
GROUP_SUFFIX = " Rounds"
# The page spells two materials differently from the API's names.
MATERIAL_ALIASES = {"Combined Materials": "Combined", "Armor steel": "ArmoredSteel"}
# name, damage, penetration, armor damage, accuracy, recoil, light/heavy bleed,
# speed, then one cell per armor class.
STATS = ("penetration_power", "armor_damage", "accuracy", "recoil",
         "light_bleed", "heavy_bleed", "speed")
ARMOR_CLASSES = 6
# name + damage + the stats above + one cell per armor class
CHART_WIDTH = 2 + len(STATS) + ARMOR_CLASSES


def norm_name(value):
    return re.sub(r"[^a-z0-9]+", "", (value or "").lower())


# --- fetch ---------------------------------------------------------------

def fetch(refresh=False):
    """The page wikitext, from the cache unless it is missing or --refresh."""
    if os.path.exists(RAW) and not refresh:
        with open(RAW, encoding="utf-8") as fh:
            payload = json.load(fh)
    else:
        url = API.format(title=urllib.parse.quote(TITLE))
        request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(request, timeout=60) as resp:
            raw = resp.read()
        payload = json.loads(raw.decode("utf-8"))
        with open(RAW, "wb") as fh:
            fh.write(raw)

        manifest = {}
        if os.path.exists(MANIFEST):
            with open(MANIFEST, encoding="utf-8") as fh:
                manifest = json.load(fh)
        manifest["ballistics"] = {
            "url": url,
            "bytes": len(raw),
            "sha256": hashlib.sha256(raw).hexdigest(),
            "fetched_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        }
        with open(MANIFEST, "w", encoding="utf-8") as fh:
            json.dump(manifest, fh, indent=2, sort_keys=True)

    pages = payload["query"]["pages"]
    if len(pages) != 1 or "missing" in pages[0]:
        raise SystemExit(f"ballistics: the wiki has no page named {TITLE!r}")
    return pages[0]["revisions"][0]["slots"]["main"]["content"]


# --- wikitext helpers ----------------------------------------------------

def tables(code):
    return [t for t in code.filter_tags() if str(t.tag) == "table"]


def body_rows(table):
    """Data rows, as lists of cells. Rows made only of `th` are headers."""
    out = []
    for row in table.contents.filter_tags():
        if str(row.tag) != "tr":
            continue
        cells = [c for c in row.contents.filter_tags() if str(c.tag) in ("td", "th")]
        if cells and all(str(c.tag) == "th" for c in cells):
            continue
        out.append(cells)
    return out


def headers(table):
    """The `!` cells in order: column labels plus any spanned sub-header."""
    return [" ".join(str(th.contents.strip_code()).split())
            for th in table.contents.filter_tags() if str(th.tag) == "th"]


def text(cell):
    """A cell's display text with all markup stripped."""
    return " ".join(cell.contents.strip_code().split())


def number(value):
    """Wiki number -> int/float, None for a blank or a non-numeric cell."""
    cleaned = (value or "").replace("+", "").strip()
    if not cleaned:
        return None
    try:
        return int(cleaned)
    except ValueError:
        try:
            return float(cleaned)
        except ValueError:
            return None


def link_title(cell):
    """(wiki page, display text) for the cell's first wikilink."""
    links = cell.contents.filter_wikilinks()
    if not links:
        return text(cell), text(cell)
    title = str(links[0].title).strip()
    return title, str(links[0].text or title).strip()


def find_table(code, label):
    """The one table carrying a column with this label."""
    want = norm_name(label)
    for table in tables(code):
        if any(norm_name(h) == want for h in headers(table)):
            return table
    raise SystemExit(f"ballistics: no table with a {label!r} column — page layout changed")


# --- parse ---------------------------------------------------------------

def parse_chart(table, groups):
    """One record per ammo row of the ammo and penetration chart."""
    classes = [h for h in headers(table) if h.isdigit()]
    if len(classes) != ARMOR_CLASSES:
        raise SystemExit(f"ballistics: expected {ARMOR_CLASSES} armor-class columns, saw {classes}")

    body = body_rows(table)
    width = max(len(cells) for cells in body) - 1          # without the caliber
    if width != CHART_WIDTH:
        raise SystemExit(f"ballistics: chart rows are {width} cells, expected {CHART_WIDTH}")

    out = []
    caliber = None
    for cells in body:
        if len(cells) == width + 1:                        # a block's first row
            caliber = text(cells[0])
            cells = cells[1:]
        if len(cells) != width:
            raise SystemExit(f"ballistics: a chart row has {len(cells)} cells")

        page, name = link_title(cells[0])
        raw_damage = text(cells[1])
        pellets = PELLETS.match(raw_damage)
        marker = " ".join(str(t.contents).strip() for t in cells[0].contents.filter_tags()
                          if str(t.tag) == "sup")
        numbers = [number(text(cell)) for cell in cells[2:]]
        out.append({
            "name": name,
            "bsg_id": None,                                # joined below
            "caliber": caliber,
            "group": groups.get(caliber),
            "damage": number(pellets.group(2)) if pellets else number(raw_damage),
            "projectile_count": int(pellets.group(1)) if pellets else 1,
            **dict(zip(STATS, numbers)),
            "subsonic": marker == "S",
            "tracer": marker == "T",
            "vs_armor_class": dict(zip(classes, numbers[len(STATS):])),
            "wiki_link": WIKI_BASE + urllib.parse.quote(page.replace(" ", "_"), safe=":_()/,."),
        })
    return out


def parse_armor_classes(table):
    """The effectiveness scale: level 0-6, its label, hits to stop, why."""
    out = []
    for cells in body_rows(table):
        if len(cells) != 4 or not text(cells[0]).isdigit():
            raise SystemExit(f"ballistics: unexpected row in the effectiveness table "
                             f"({len(cells)} cells)")
        out.append({
            "armor_class": int(text(cells[0])),
            "label": text(cells[1]),
            "bullets_stopped": text(cells[2]),
            "explanation": text(cells[3]),
        })
    return out


def parse_groups(table):
    """Caliber -> quick-selection group (pistol, pdw, rifle, shotgun, other)."""
    labels = headers(table)
    body = body_rows(table)
    if len(body) != 1 or len(labels) != len(body[0]):
        raise SystemExit("ballistics: caliber grouping is not one label row plus one list row")

    out = {}
    for label, cell in zip(labels, body[0]):
        group = C.slugify(label.removesuffix(GROUP_SUFFIX))
        for link in cell.contents.filter_wikilinks():
            out[str(link.text or link.title).strip()] = group
    return out


def parse_materials(table, reference):
    """Armor material destructibility. The API carries the same numbers in
    `reference.json`, so each row records which material it corresponds to and
    `99_verify.py` pins the two equal."""
    by_name = {norm_name(k): k for k in reference}
    out = []
    for cells in body_rows(table):
        if len(cells) != 3:
            raise SystemExit(f"ballistics: unexpected row in the material table "
                             f"({len(cells)} cells)")
        material = text(cells[0])
        key = MATERIAL_ALIASES.get(material, material)
        out.append({
            "material": material,
            "reference": by_name.get(norm_name(key)),
            "destructibility": number(text(cells[1])),
            "explosive_destructibility": number(text(cells[2])),
        })
    return out


def build():
    code = mwparserfromhell.parse(fetch(refresh="--refresh" in sys.argv))

    groups = parse_groups(find_table(code, "Rifle Rounds"))
    ammo = parse_chart(find_table(code, "Penetration power"), groups)
    classes = parse_armor_classes(find_table(code, "Effectiveness level"))
    reference = json.load(open(os.path.join(C.CANON, "reference.json"), encoding="utf-8"))
    materials = parse_materials(find_table(code, "Destructibility"),
                                reference["armor_materials"])

    # The page is name-only; the app joins on the BSG id. Rows the snapshot
    # does not have stay unmatched with a null id rather than being dropped.
    by_name = {}
    for item in C.load_jsonl(os.path.join(C.CANON, "items.ndjson")):
        if (item.get("properties") or {}).get("ammoType"):
            by_name.setdefault(norm_name(item.get("name")), item["bsg_id"])
    for row in ammo:
        row["bsg_id"] = by_name.get(norm_name(row["name"]))

    matched = [r["bsg_id"] for r in ammo if r["bsg_id"]]
    if len(matched) != len(set(matched)):
        dupes = sorted({b for b in matched if matched.count(b) > 1})
        raise SystemExit(f"ballistics: {len(dupes)} item(s) matched twice: {dupes[:5]}")

    return ammo, classes, materials


def main():
    ammo, classes, materials = build()
    C.write_jsonl(os.path.join(C.CANON, "ballistics.ndjson"), ammo)
    C.write_jsonl(os.path.join(C.CANON, "armor_classes.ndjson"), classes)
    C.write_jsonl(os.path.join(C.CANON, "armor_materials.ndjson"), materials)

    matched = sum(1 for r in ammo if r["bsg_id"])
    unresolved = [m["material"] for m in materials if not m["reference"]]
    print(f"ballistics      {len(ammo)} rounds, {matched} joined to items, "
          f"{len(ammo) - matched} not in the snapshot")
    print(f"armor classes   {len(classes)} levels 0-{max(c['armor_class'] for c in classes)}")
    print(f"armor materials {len(materials)} rows, "
          f"{len(unresolved)} with no reference.json counterpart {unresolved or ''}")


if __name__ == "__main__":
    main()
