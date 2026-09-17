# Verification

| # | check | result |
| ---: | --- | --- |
| 1 | PASS | canonical files exist — all present |
| 2 | PASS | items unique bsg_id — 5481 distinct of 5481 |
| 3 | PASS | items >= 5000 — 5481 |
| 4 | PASS | no placeholder display names — 0 placeholders |
| 5 | PASS | every item has a name — 5481 named |
| 6 | PASS | every item has a slug — all 5481 |
| 7 | PASS | name_source recorded for every item — all 5481 |
| 8 | PASS | tasks unique id — 517 distinct of 517 |
| 9 | PASS | every task has a name + slug — all 517 |
| 10 | PASS | barter traders resolve — 8 distinct, all resolved |
| 11 | PASS | craft stations resolve — 8 distinct |
| 12 | PASS | task traders resolve — 11 distinct, all resolved |
| 13 | PASS | task map ids resolve — 13 distinct, all resolved |
| 14 | PASS | barter offered items resolve — 713 distinct, all resolved |
| 15 | PASS | craft products resolve — 203 distinct, all resolved |
| 16 | PASS | craft required items resolve — 247 distinct, all resolved |
| 17 | PASS | barter required items resolve — 260 distinct, all resolved |
| 18 | PASS | task objective items resolve — 3759 distinct, all resolved |
| 19 | PASS | task reward items resolve — 392 distinct, all resolved |
| 20 | PASS | hideout build items resolve — 119 distinct, all resolved |
| 21 | PASS | task leads_to resolve — 28 distinct, all resolved |
| 22 | PASS | every required slot is fillable — 624 required slots, all fillable |
| 23 | PASS | slot allowed items resolve — 2385 distinct, all resolved |
| 24 | PASS | trader count is the full roster — >=14 = 16 |
| 25 | PASS | craft stations == 8 — ==8 = 8 |
| 26 | PASS | tasks reference maps — 13 distinct map ids |
| 27 | PASS | kappa tasks present — kappa = 13 |
| 28 | PASS | hideout has Workbench — True |
| 29 | PASS | map names include Factory — True |
| 30 | PASS | reference has 79 player levels — ==79 = 79 |
| 31 | PASS | reference has 123 achievements — 123 |
| 32 | PASS | M4A1 resolves with mod slots — Colt M4A1 5.56x45 assault rifle — 6 slots, 1 buy routes |
| 33 | PASS | 'First in Line' task named — First in Line by therapist (2 objectives) |
| 34 | PASS | every achievement has a name — all 123 |
| 35 | PASS | no item name is derived — all official; sources=['officialwiki', 'tarkovdev:items_en', 'tarkovdev:tasks_en', 'tarkovmarket'] |
| 36 | PASS | index barter unlocks are routable — 45 unlocked items all gated |
| 37 | PASS | barter unlocks present, none in failure — 457 unlocks (98 barter), 0 in failure |
| 38 | PASS | unlock sources are tagged — sources=['tarkovdev', 'tarkovunlockables'] |
| 39 | PASS | objective descriptions localised — 1444 described |
| 40 | PASS | wiki conflict relations resolve — api=11312, wiki=2276 (2081 corroborated, 195 wiki-only) |
| 41 | PASS | wiki compatibility relations resolve — 10775 edges over 1785 items |
| 42 | PASS | wiki trader offers parse and corroborate — 2760 offers over 2525 items, 2633 (95%) corroborated, 2954 internal ids |
| 43 | PASS | wiki trade/craft tables corroborate — trades 379/443 (85%), crafts 199/213 (93%), ballistics 1510/1522 (99%), 12 numeric disagreements |
| 44 | PASS | task graph is a well-formed DAG — acyclic, depth 18, kappa 16, lightkeeper 7 |
| 45 | PASS | wiki weapon variants map 1:1 to presets — 103 variants over 52 base weapons, 101 matched 1:1, 1063 attachments |
| 46 | PASS | wiki build parts agree with preset parts — 99/101 wiki part lists are a subset of their preset's parts |
| 47 | PASS | map boss names resolved — 129 entries named |
| 48 | PASS | map transit names resolved — 33 entries named |
| 49 | PASS | map extract names resolved — 152 entries named |
| 50 | PASS | buy routes are all tarkovdev + priced — 2658 tdev rows (2658 priced) + 3202 index offers (78 with variant) |
| 51 | PASS | buy coverage (tdev + index union) >= 2,900 — buyable items = 2965 |
| 52 | PASS | sell_to rows have no null price — 25488 rows, 25281 positive, 207 zero |
| 53 | PASS | sqlite file exists — 52187136 |
| 54 | PASS | sqlite integrity_check — ok |
| 55 | PASS | sqlite item count matches canonical — ==5481 = 5481 |
| 56 | PASS | fts search finds M4A1 — 3+ hits, first=Colt M4A1 5.56x45 assault rifle |
| 57 | PASS | fts search finds LEDX — 2+ hits, first=LEDX Skin Transilluminator |
| 58 | PASS | view v_item_price returns — 3540 priced items |
| 59 | PASS | sqlite trader levels — ==42 = 42 |
| 60 | PASS | sqlite slot graph present — 39910 allowed-item edges |
| 61 | PASS | sqlite acquisition present — 7903 routes |
| 62 | PASS | category paths backfilled — 35643/35643 populated |
| 63 | PASS | route costs are complete or null, never faked — 929 rows, 921 priced, 8 incomplete (null cost), 1 legitimately zero-cost (no inputs), 146 cheaper than flea |
| 64 | PASS | weapon build stats present — 171 weapons, 109 with capped combinatorial counts |
| 65 | PASS | all analysis steps have run — item_acquisition_cost, weapon_build_stats |
| 66 | PASS | armor materials join to items — 326 armored items joined to 8 materials |
| 67 | PASS | special-slot ids resolve to items or categories — 37 ids = 28 items + 9 categories; 44 items carry the specialSlot type |
| 68 | PASS | every wiki infobox id is attached to its item — 4115/5481 items carry a wiki block; 216 ids filled from 156 multi-id pages; 1 wiki-only item(s); 22 title/name differences |
| 69 | PASS | README row counts match the data — 9 documented counts match (barters=789, categories=200, crafts=214, hideout_stations=26...) |
| 70 | PASS | map nests are normalized without loss — 5 map tables complete (map_boss_helpers=192, map_bosses=129, map_enemies=92, map_extracts=152, map_transits=33) |
| 71 | PASS | no table is entirely empty — 57 tables all non-empty |
| 72 | PASS | wiki-derived relations loaded — item_wiki_slots=26786, item_wiki_meta=4115, item_wiki_trader_offers=2760, item_conflicts=13588, item_compatibility=10775, item_grids=903 |

**72/72 checks passed.**
