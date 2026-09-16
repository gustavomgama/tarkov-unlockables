# Verification

| # | check | result |
| ---: | --- | --- |
| 1 | PASS | canonical files exist — all present |
| 2 | PASS | items unique bsg_id — 5480 distinct of 5480 |
| 3 | PASS | items >= 5000 — 5480 |
| 4 | PASS | no placeholder display names — 0 placeholders |
| 5 | PASS | every item has a name — 5480 named |
| 6 | PASS | every item has a slug — all 5480 |
| 7 | PASS | name_source recorded for every item — all 5480 |
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
| 35 | PASS | no item name is derived — all official; sources=['tarkovdev:items_en', 'tarkovdev:tasks_en', 'tarkovmarket'] |
| 36 | PASS | index barter unlocks are routable — 45 unlocked items all gated |
| 37 | PASS | barter unlocks present, none in failure — 457 unlocks (98 barter), 0 in failure |
| 38 | PASS | unlock sources are tagged — sources=['tarkovdev', 'tarkovunlockables'] |
| 39 | PASS | objective descriptions localised — 1444 described |
| 40 | PASS | wiki conflict relations resolve — api=11312, wiki=2246 (2054 corroborated, 192 wiki-only) |
| 41 | PASS | wiki compatibility relations resolve — 9131 edges over 1645 items |
| 42 | PASS | wiki trader offers parse and corroborate — 2536 offers over 2371 items, 2490 (98%) corroborated, 2784 internal ids |
| 43 | PASS | task graph is a well-formed DAG — acyclic, depth 18, kappa 13, lightkeeper 7 |
| 44 | PASS | map boss names resolved — 129 entries named |
| 45 | PASS | map transit names resolved — 33 entries named |
| 46 | PASS | map extract names resolved — 152 entries named |
| 47 | PASS | buy routes are all tarkovdev + priced — 2658 tdev rows (2658 priced) + 3202 index offers (78 with variant) |
| 48 | PASS | buy coverage (tdev + index union) >= 2,900 — buyable items = 2965 |
| 49 | PASS | sell_to rows have no null price — 25488 rows, 25281 positive, 207 zero |
| 50 | PASS | sqlite file exists — 51167232 |
| 51 | PASS | sqlite integrity_check — ok |
| 52 | PASS | sqlite item count matches canonical — ==5480 = 5480 |
| 53 | PASS | fts search finds M4A1 — 3+ hits, first=Colt M4A1 5.56x45 assault rifle |
| 54 | PASS | fts search finds LEDX — 2+ hits, first=LEDX Skin Transilluminator |
| 55 | PASS | view v_item_price returns — 3540 priced items |
| 56 | PASS | sqlite trader levels — ==42 = 42 |
| 57 | PASS | sqlite slot graph present — 39910 allowed-item edges |
| 58 | PASS | sqlite acquisition present — 7903 routes |
| 59 | PASS | category paths backfilled — 35643/35643 populated |
| 60 | PASS | route costs are complete or null, never faked — 929 rows, 921 priced, 8 incomplete (null cost), 1 legitimately zero-cost (no inputs), 146 cheaper than flea |
| 61 | PASS | weapon build stats present — 171 weapons, 109 with capped combinatorial counts |
| 62 | PASS | no table is entirely empty — 50 tables all non-empty |
| 63 | PASS | wiki-derived relations loaded — item_wiki_slots=25108, item_wiki_meta=3899, item_wiki_trader_offers=2536, item_conflicts=13558, item_compatibility=9131, item_grids=903 |

**63/63 checks passed.**
