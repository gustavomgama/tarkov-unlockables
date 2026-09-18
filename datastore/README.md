# Tarkov datastore

An organized, cross-source dataset for *Escape from Tarkov*, built from
`offlinedata/` plus the tarkov.dev localization and reference endpoints.

**Start here:** [`docs/01_domain_model.md`](docs/01_domain_model.md) — how
items, traders, barters, crafts, hideout, tasks and the flea market actually
interlock. Every other file assumes it.

## Layout

```
datastore/
  README.md                    this file
  docs/01_domain_model.md      the game's entity model + how routes/gates work
  docs/02_sources.md           every source, its provenance, and its known gaps
  docs/03_data_dictionary.md   field-by-field reference for every output
  docs/04_db_mapping.md        canonical <-> Rails Postgres schema, and what the DB lacks
  fetched/                     tarkov.dev *_en + maps + hideout, with manifest.json
  canonical/                   the dataset: one NDJSON per entity + reference.json
  tarkov.sqlite3               indexed, full-text-searchable build of canonical/
  reports/                     coverage, build stats, verification results
  scripts/                     the reproducible pipeline
```

## The dataset

| file | rows | what it is |
| --- | ---: | --- |
| `canonical/items.ndjson` | 5,481 | every item with resolved name, verbatim `properties`, mod slots, grids, flea economy, trader trade, **acquisition routes** and **reverse usage** |
| `canonical/tasks.ndjson` | 517 | full quest graph: gates, typed objectives, rewards, unlocks (incl. task-gated barters the API omits), maps |
| `canonical/barters.ndjson` | 789 | trader barter offers with full recipes, limits, task gates |
| `canonical/crafts.ndjson` | 214 | hideout recipes with station/level/duration and tool flags |
| `canonical/traders.ndjson` | 16 | trader roster with loyalty levels, currencies, buy rules |
| `canonical/hideout_stations.ndjson` | 26 | stations + 68 levels + build requirements (incl. found-in-raid) |
| `canonical/maps.ndjson` | 17 | maps with raid duration, extracts, transits, bosses |
| `canonical/categories.ndjson` | 200 | internal + handbook category trees with paths |
| `canonical/weapon_variants.ndjson` | 103 | wiki-named weapon builds with their exact attachment lists, mapped 1:1 to tarkovdev presets |
| `canonical/ballistics.ndjson` | 190 | one row per round from the wiki's ballistics chart: damage, penetration, armor damage, accuracy, recoil, bleeds, speed and **effectiveness against armor class 1-6** |
| `canonical/armor_classes.ndjson` | 7 | the wiki's effectiveness scale: what level 0-6 means and how many hits it takes |
| `canonical/armor_materials.ndjson` | 8 | the wiki's destructibility table, kept as a cross-check of the API's copy |
| `canonical/reference.json` | — | levels, skills, mastery, armor materials, achievements, prestige |

Price it: `item_acquisition_cost` (SQLite) costs every barter and craft by
pricing its consumed inputs (tools excluded) from `avg24h_price` →
`last_low_price` → `base_price`. A recipe with any unpriced input is recorded
`complete = 0` with a **null** cost — never a fake zero. `v_item_acquisition_cost`
adds the item's own flea price and the difference.

Key structure: **the BSG id is the join key everywhere**, and every item
carries both directions of the graph —
```
acquisition:  buy_from trader · barter · craft · task reward · hideout craft
used_in:      craft input · barter requirement · hideout build cost · quest objective
```

so "how do I get X" and "what is X for" are both single lookups.

The ballistics files come from the wiki's [Ballistics](https://escapefromtarkov.fandom.com/wiki/Ballistics)
page, the only source that publishes **how effective each round is against
each armor class** (and the scale those six numbers are read on). The app reads
the levels into `items.armor_class_effectiveness` and treats **level 4 and up
as penetrating that class** (`Item::Ammo#defeats_class`; rounds without a chart
row fall back to the penetration estimate). Every other column on that page
repeats a value the dataset already holds, so `99_verify.py` compares them
rather than trusting the parse: 1,000+ values against the API's ammo properties
at ≥95% agreement, and both armor-material destructibility numbers against
`reference.json`.

## Rebuild

```bash
cd datastore/scripts
~/.pyvenv-tarkov/bin/python 10_fetch.py           # cache tarkov.dev *_en/maps/hideout (idempotent)
~/.pyvenv-tarkov/bin/python 20_build_canonical.py # offlinedata + fetched -> canonical/
~/.pyvenv-tarkov/bin/python 25_ballistics.py      # wiki ballistics page -> canonical/ (fetches once)
~/.pyvenv-tarkov/bin/python 30_build_sqlite.py    # canonical/ -> tarkov.sqlite3
~/.pyvenv-tarkov/bin/python 99_verify.py          # every check, exits non-zero on failure
                                                  # (the count is in reports/04_verification.md)
```

Or run the whole thing: `datastore/scripts/run.sh` (steps in order, exits on first failure).

Reconnaissance and coverage reports:

```bash
~/.pyvenv-tarkov/bin/python 00_recon.py    # structural dump of every offlinedata file
~/.pyvenv-tarkov/bin/python 01_coverage.py # source overlap, name resolution, integrity -> reports/01_coverage.md
```

Requirements: python 3.14 venv with stdlib only (`~/.pyvenv-tarkov/bin/python`);
`fetched/` is committed-in-spirit but regenerable, and the build works offline
once it exists. `offlinedata/tarkovmarket/` is gitignored — if it is missing,
market names/URLs are simply absent and the build still succeeds.

## Query it

SQLite (stdlib `sqlite3`, FTS5 enabled):

```sql
-- how do I get a LEDX?
SELECT route, trader_slug, station, level FROM item_acquisition
WHERE bsg_id = '5c0530ee86f774697952d952';
-- barter|therapist|3   craft|Medstation|3   task_reward|… (×3)

-- flea vs best trader sell
SELECT name, avg24h_price, best_trader_sell, min_level_for_flea FROM v_item_price
WHERE bsg_id = '5c0530ee86f774697952d952';
-- LEDX Skin Transilluminator | 583060 | 494700 | 35

-- what does a Workbench recipe cost? (is_tool=1 is NOT consumed)
SELECT i.name, cr.count, cr.is_tool FROM craft_required cr
JOIN items i ON i.bsg_id = cr.bsg_id
WHERE cr.craft_id = (SELECT id FROM crafts WHERE product_bsg_id='5d0376a486f7747d8050965c' LIMIT 1);
-- Flat screwdriver (Long)|1|1   Screwdriver|1|1   Pliers Elite|1|1
-- Military COFDM Wireless Signal Transmitter|1|0

-- which mods fit an M4A1 barrel slot?
SELECT COUNT(*) FROM item_slot_allowed sa
JOIN item_slots s ON s.id = sa.slot_id
WHERE s.bsg_id='55d355e64bdc2d962f8b4569' AND s.name_id='mod_barrel';
-- 11

-- full-text search
SELECT bsg_id, name FROM items_fts WHERE items_fts MATCH 'ledx';

-- who spawns on Customs with what escort, and where can I leave?
SELECT b.name, b.spawn_chance, h.helper_name, h.chance, h.count
FROM map_bosses b LEFT JOIN map_boss_helpers h
  ON h.map_id = b.map_id AND h.boss_index = b.boss_index
WHERE b.map_id = (SELECT id FROM maps WHERE slug='customs') AND b.mob='bossBully';
-- Reshala|0.6|Reshala Guard|1.0|4

SELECT name, faction FROM map_extracts e JOIN maps m ON m.id = e.map_id
WHERE m.slug='interchange' AND faction IN ('pmc','shared');
-- Saferoom Exfil|pmc  …  Hole in the Fence|shared
```

Map nests are normalized too, so extracts/bosses/transits are queryable without
`json_each`. Their source lists repeat ids — the same Gate 3 extract serves both
factions, The Lab lists `PmcBot` 16 times — so the tables key on the source's
position (`ordinal`, `boss_index`) rather than on those ids.

Python:

```python
import sqlite3
con = sqlite3.connect("datastore/tarkov.sqlite3")
con.execute("SELECT name, avg24h_price FROM items WHERE caliber='Caliber556x45NATO' AND avg24h_price>0 ORDER BY avg24h_price DESC LIMIT 5").fetchall()
```

NDJSON (stream-friendly):

```bash
jq -c 'select(.slug=="colt-m4a1-556x45-assault-rifle") | {name, slots: (.slots|length), acquisition}' \
  datastore/canonical/items.ndjson
```

## Reports

- `reports/00_recon.md` — structural dump of every offlinedata source.
- `reports/01_coverage.md` — source sizes, pairwise overlap, name resolution, cross-reference integrity.
- `reports/02_build_stats.md` — canonical row counts, name provenance, file sizes.
- `reports/03_sqlite_stats.md` — table row counts + `integrity_check`.
- `reports/04_verification.md` — every check and its result.
- `reports/05_task_graph.md` — quest-graph shape: depth, chain, Kappa/Lightkeeper closures, workload per trader and map.
- `reports/06_route_economics.md` — barter/craft recipes priced with snapshot flea prices; 146 routes beat the flea price outright.
- `reports/07_weapon_builds.md` — how many distinct configurations each weapon has; 109 of 171 weapons exceed 10¹² builds, 624 required slots, none unfillable; the wiki's build parts are a subset of the matching preset's in 99/101 cases.
- `reports/08_wiki_crosscheck.md` — cross-source validation. The wiki's 443 trade rows and 213 craft outputs matched against the dataset (85%, 93%), and 1,522 ammo ballistics values (damage, penetration, velocity, recoil...) compared against the API's ammo properties: 99% agree, and the 12 that do not are listed individually.

## Known limits

1. **Names come from four places, none of them slug-derived.** 5,312 from
   `items_en`; 135 quest items from `tasks_en` (they are absent from `/items`
   and from `items_en`); 32 from the tarkov-market snapshot; 2 from the wiki
   infobox title, for ids the API does not carry at all. `name_source` records
   which, and no item falls back to a slugified id. The wiki is the newest of
   the four, so re-check it when the API catches up on those ids.
2. **No bulk flea prices from tarkov-market** — the offlinedata bulk file has
   no price fields, so prices are tarkovdev's.
3. **Generation is snapshot-bound.** Items live as of the 2026-09-03 snapshot;
   the localization files are 2026-09-16. Ids are stable, but items added
   after the snapshot are not in the dataset.
4. **`types` is a bag of flags, not a partition** — check `noFlea`/`preset`
   explicitly.
5. **`acquisition.buy` and `acquisition.index_offers` are separate on
   purpose.** `buy` is tarkovdev's priced purchase (2,598 items);
   `index_offers` is the derived index's trader/loyalty/variant claim
   (2,965 items, 78 of them variant-labelled, unpriced). Their union is what
   makes an item "buyable". There is no `index_hideout` route — the index's
   hideout claims are a strict subset of `craft` and were dropped.
6. **The ballistics chart is name-joined and snapshot-bound.** 186 of its 190
   rounds resolve to an item by normalized name; the four that do not
   (`7.62x51mm Ball 11 Long Range`, `7.62x54mm R Tungsten Carbide AP`,
   `12.7x108mm BZT-44M`, `12.7x108mm B-32`) are items the snapshot lacks, and
   they keep a null `bsg_id` rather than being dropped. The page's `*`
   footnote — the effectiveness numbers assume every projectile hits — is not
   modelled, and a `9x35` damage cell is split into `projectile_count` 9 and
   `damage` 35 so it stays in the API's per-projectile unit.
