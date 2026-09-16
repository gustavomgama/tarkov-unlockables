# Escape from Tarkov — domain model

This is the mental model the dataset is organized around. Every entity,
identifier and relationship below is verified against the data in
`canonical/` (counts are from the 2026-09-03 tarkov.dev snapshot, enriched
with the 2026-09-16 localization build).

The one-line version: **Tarkov is a loot economy where every item's value is
determined by the routes that can produce it (trader, barter, craft, task
reward, flea market), and every route is gated by a player's level, trader
loyalty, hideout level, and quest progress.** The dataset is therefore
organized item-first, with acquisition and usage routes attached to each item,
and the gates (level / loyalty / station level / quest) attached to each route.

---

## 1. Identifier system

There are two completely separate namespaces, and mixing them up is the main
source of confusion in this data:

| namespace | form | used by | example |
| --- | --- | --- | --- |
| **BSG id** | 24-char lowercase hex | items, quest items, container contents, mod slots, hideout items, task objective items, hideout station ids, map ids, trader ids | `5447a9cd4bdc2dbd208b4567` |
| **slug / normalizedName** | kebab-case english | human-facing key for items, traders, tasks, categories, maps | `colt-m4a1-556x45-assault-rifle` |

Trader ids and map ids are 24-hex **but are not items**. Craft station ids
and barter `trader` ids are also 24-hex and are **not items**. So a bare
24-hex id cannot be assumed to be an item — resolve it against the right
table. Where tarkov.dev returned a raw id where a slug would be friendlier
(e.g. `buyFromTrader[].trader`) the canonical build resolved it to
`trader_slug`, keeping the raw id alongside.

A third namespace appears in the wiki infobox: the game's own `internal_id`
(`weapon_colt_m4a1_556x45`), available for 2,784 items and stored as
`wiki.internal_id`. It is not used as a key — the BSG id remains the join key —
but it is the string the game files use.

The BSG id is the only identifier present in **every** source, which is why
the canonical dataset is keyed by it.

---

## 2. Items — the atom

5,480 distinct item records (`canonical/items.ndjson`). The universe is the
union of four sets: 5,312 from `tarkovdev/items.json`, 43 only in
tarkov-market, 4 only in the wiki, and 121 quest items that appear in no other
source (the other 14 of the 135 quest items overlap the main sets). 135 items
are flagged `quest_item: true` — real items that exist only to be handed in or
planted, and that the main `/items` endpoint does not return.

### 2.1 Three parallel taxonomies

The same item is classified three ways, and they answer different questions:

| field | shape | what it is | example |
| --- | --- | --- | --- |
| `types[]` | flat list of game-facing tags | how the game's UI groups it; multi-valued | `["gun","wearable"]`, `["mods"]`, `["ammo","ammoBox","noFlea"]` |
| `categories` | id tree, root `item`, depth ≤ 6 | the internal BSG category graph; **inheritance** | `weapon/assault-rifle` |
| `handbook_categories` | id tree, 14 roots | the player-facing handbook tree, used by the flea filters | `weapons/assault-rifles` |

`types` carries behaviour flags as well as kinds: `noFlea` (cannot be traded
on the flea market), `barter` (obtainable via barter), `preset` (a saved
weapon build, not a physical item), `ammoBox` (bulk ammo pack),
`specialSlot`, `markedOnly` (spawns only from marked rooms), `poster`,
`pocketGear`. 26 distinct values. Treat `types` as flags when it matters
(especially `noFlea`), not as a clean partition.

`categories` is the one with parent/child links. The tree is
`item → compound-item → weapon → assault-rifle` etc. Use `categories.paths`
for the full chain and `categories.leaves` for the direct tags.

### 2.2 Type-specific properties

4,164 items carry a `properties` block whose `propertiesType` selects one of
**28 schemas**. The important ones and their distinguishing fields:

| propertiesType | n | notable fields |
| --- | ---: | --- |
| `ItemPropertiesWeaponMod` | 1,638 | `ergonomics`, `recoilModifier`, `accuracyModifier`, `slots`, `heatFactor`, `coolingFactor` |
| `ItemPropertiesPreset` | 484 | `baseItem`, `default`, `moa`, `recoilVertical/Horizontal` — a **build**, not an item |
| `ItemPropertiesKey` | 256 | `uses` |
| `ItemPropertiesScope` | 230 | `zoomLevels`, `sightingRange`, `sightModes`, `zeroingDistances` |
| `ItemPropertiesMagazine` | 224 | `capacity`, `allowedAmmo`, `loadModifier`, `malfunctionChance` |
| `ItemPropertiesAmmo` | 200 | `damage`, `penetrationPower`, `armorDamage`, `fragmentationChance`, `ricochetChance`, `initialSpeed`, `ballisticCoeficient`, bleed/misfire/heat factors |
| `ItemPropertiesBarrel` | 196 | `centerOfImpact`, `deviationCurve/Max`, `coolingFactor` |
| `ItemPropertiesWeapon` | 171 | `caliber`, `fireRate`, `fireModes`, `allowedAmmo`, `defaultPreset`, `presets`, `slots` |
| `ItemPropertiesHelmet` / `ArmorAttachment` / `Armor` / `ChestRig` / `Glasses` | 109 / 83 / 47 / 91 / 37 | `class` (1–6), `durability`, `bluntThroughput`, `zones`, `armorSlots`, `material`, penalties |
| `ItemPropertiesContainer` / `Backpack` / `ChestRig` | 43 / 47 / 91 | `capacity`, `grids` (grid cells) |
| `ItemPropertiesFoodDrink` / `Stim` / `MedKit` / `Painkiller` / `MedicalItem` / `SurgicalKit` | 46 / 21 / 6 / 6 / 8 / 2 | `energy`, `hydration`, `stimEffects`, `cures`, `useTime`, `hitpoints` |
| `ItemPropertiesMelee` | 25 | `slashDamage`, `stabDamage` |
| `ItemPropertiesHeadphone` | 25 | ambient/compressor audio model |
| `ItemPropertiesGrenade` | 13 | `fuse`, `fragments`, `min/maxExplosionDistance`, `contusionRadius` |

`properties` is stored **verbatim** in both `items.ndjson` and the SQLite
`items.properties` column. Convenience projections (`armor_class`, `damage`,
`penetration_power`, `caliber`, `ergonomics`, `max_durability`, `uses`) are
extracted into columns, but the raw block is never discarded.

### 2.3 Modding graph

3,564 mod slots (`item_slots`) with **39,910 allowed-item edges**
(`item_slot_allowed`). Each slot belongs to a parent item and carries
`allowed_items` / `allowed_categories` plus exclusions. A weapon's `slots`
therefore *is* its build tree: complete a weapon by recursively picking one
allowed item per required slot. Compats come with `conflictingItems` /
`conflictingSlotIds` / `conflictingCategories` on the item.

`preset` items are pre-built weapons: `properties.baseItem` is the receiver
they are built on, `properties.default` marks the factory preset, and the
preset appears in the base weapon's `properties.presets`. 484 presets.

Compatibility has a second, independent view from the wiki: its page sections
list, per item, the exact items a slot accepts (1,068 items), a "Compatibility"
field naming the base weapon a mod belongs to (`compatibility`, 9,131
relations over 1,645 items), and an explicit "Conflicting items" list
(`conflicts.wiki_items`, 2,246 relations — 2,054 of which corroborate the
API's 11,312 and 192 of which are new). Where the two sources disagree the
wiki's mod list is a strict subset of the API's, so the API is authoritative
for what fits and the wiki is the check.

### 2.4 Physical & economy fields

`physical`: `width`/`height` (grid footprint), `weight`, `stack_max_size`,
`has_grid`, `background_color` (inventory tint), `discard_limit`.
`economy`: `base_price` (handbook value — the basis for trader buy prices,
insurance and flea listing), live flea stats (`avg24h_price`, `low24h_price`,
`high24h_price`, `last_low_price`, `change_last_48h`, `last_offer_count`),
`min_level_for_flea` (the player level required to trade it on the flea), and
`last_scan`. 3,540 items had a flea price at snapshot time; the other ~1,900
are not flea-tradable or were never scanned (see `noFlea` / `bannedOnFlea`).

---

## 3. Traders and the loyalty model

16 trader-like entities. Eight are the classic traders, the rest are
special NPCs:

| slug | name | currency | role |
| --- | --- | --- | --- |
| `prapor` | Prapor | RUB | low-tier weapons, ammo, grenades |
| `therapist` | Therapist | RUB | meds, keys, high-value buyback |
| `fence` | Fence | RUB | resells player-sold loot; reputation levels |
| `skier` | Skier | RUB | cheap weapons, barter specialist |
| `peacekeeper` | Peacekeeper | **USD** | NATO weapons/ammo, dollars |
| `mechanic` | Mechanic | RUB | high-tier weapons, mods, gunsmith tasks |
| `ragman` | Ragman | RUB | clothing, rigs, bags |
| `jaeger` | Jaeger | RUB | hunting gear — **unlocked by the `introduction` task** |
| `lightkeeper` | Lightkeeper | RUB | endgame task giver (7 lightkeeper-gated tasks) |
| `ref` | Ref | RUB | arena + free rewards (20 tasks) |
| `btr-driver` | BTR Driver | — | map transit NPC (19 tasks) |
| `radio-station`, `taran`, `mr-kerman`, `voevoda`, `survivor` | — | — | event/side NPCs, no shop levels |

Shop mechanics:

- `levels[]` — loyalty levels LL1–LL4. Each level has
  `required_player_level`, `required_reputation`, `required_commerce`,
  `pay_rate`, `insurance_rate`, `repair_cost_multiplier`. 42 level rows total.
  This is the gate on every currency purchase (`item_currencies` in the Rails
  DB, `item_trade` here).
- `currency` — the trader only accepts their own currency (USD for
  Peacekeeper), which is why `currency` is stored per purchase as well as per
  trader.
- `buy_allowed` / `buy_prohibited` — category- and item-level rules
  (prohibited items are not sold, only bought back).
- `reset_time` — when their stock refreshes.

A currency purchase is `item_trade(direction='buy_from')` with
`min_trader_level` and `buy_limit`. A **barter** is a different row type
entirely (§4).

The wiki's item pages carry an independent, hand-maintained seller list in
their infobox (`[[Peacekeeper]] LL3: Standard<br/>…`), parsed into
`wiki.trader_offers` — 2,536 offers over 2,371 items, 206 naming a preset
variant. 98% of them name a trader that the API's buy routes also mention, and
78% match on (trader, loyalty) exactly; the 2 items the wiki credits to a
trader with no API buy route are event/quest items. Where the wiki is the only
source of a variant name it is kept verbatim rather than guessed.

---

## 4. Barters vs purchases vs crafts

Three distinct production routes, all present as separate entities:

### 4.1 Barter (789 rows, `barters.ndjson`)

Barter **out** a set of items for one offered item, at one trader, gated by
`min_trader_level` and optionally a `task_unlock` (66 of 789 are task-gated in
tarkovdev). A further **45 items are unlocked by barter through a task** and
appear in *no* tarkovdev barter at all — 13 of them exist only as a recipe in
the derived index, because the JSON API exposes no `barterUnlock` reward. Those
recipes are merged into `acquisition.barter` and into the task's
`finish_rewards.barter_unlock`, tagged `source: tarkovunlockables`
(51 such routes).

```
required_items[] (item + count)  ──trader──►  offered_item (item + count)
```

`buy_limit` is the per-player purchase cap and `restock_amount` the trader's
total stock. Required items can themselves be flea-bought, so a barter's
real price is `Σ(count × item_price)`, not a fixed number.

### 4.2 Craft (214 rows, `crafts.ndjson`)

Hideout production at one of **8 craft stations** (Workbench, Lavatory,
Medstation, Intelligence center, Nutrition unit, Water collector, Bitcoin
farm, Booze generator), gated by station `level` and optionally `task_unlock`
(33 of 214).

```
required_items[] (item + count + is_tool) ──station@level, duration──► product_item
```

`is_tool` is the crucial nuance: 172 of the required-item rows are **tools**
that must be present but are **not consumed** (e.g. a hand drill). A tool must
never be counted as a material cost. A handful of crafts are edition-locked
(`game_editions`).

Note that hideout **building** is a third thing: each hideout station level
consumes items (`hideout_level_items`, 317 rows, 76 of them requiring
`found_in_raid: true` items). That is the item's `used_in.hideout_build`
relation, not a craft.

### 4.3 Task reward (989 reward-item rows)

Tasks hand out items on start or finish (`start_rewards` / `finish_rewards` /
`failure_outcome`). 392 distinct items are given by at least one task.

### 4.4 The `acquire` / `used_in` symmetry

Every item row carries both directions:

```
acquisition: { buy, index_offers, barter, craft, task_rewards }
used_in:     { crafts, barters, hideout_build, task_objectives }
```

`acquisition` answers *how do I get this?*; `used_in` answers *what is this
for?* — which is the question that actually determines an item's value.
1,955 items have no acquisition route (pure loot/quest items) and 1,602 have
no recorded use; both counts are expected and are the interesting ones.

---

## 5. The flea market

The player-to-player market. It is not an entity in the API; it is a set of
constraints on items plus price fields:

- `min_level_for_flea` — the character level required to trade the item.
- `noFlea` (in `types`) / `bannedOnFlea` (tarkov-market) — cannot be listed.
- `avg24h_price` / `low24h_price` / `high24h_price` / `last_low_price` —
  rolling price statistics; `change_last_48h_percent` the trend.
- `base_price` — the handbook value, which is *not* the flea price; it is the
  anchor for trader buy prices and insurance payouts.

Gun builds and `noFlea` items are the classic constraints: presets cannot be
listed, and ammunition packs and quest items are commonly `noFlea`.

---

## 6. Tasks (quests)

517 tasks (`tasks.ndjson`). Each is a node in a **DAG** with gates and
rewards, given by exactly one trader.

### 6.1 Identity and display names

`id` is the BSG task id; `slug` is `normalizedName`; the name comes from
`tasks_en` (`<id> name`). 52 rows in the derived unlockables index had a blank
`bsg_id` — those are dropped rather than guessed.

### 6.2 Gates

| gate | field |
| --- | --- |
| character level | `min_player_level` |
| previous tasks | `task_requirements[]` (`{task, status}`) + `previous_tasks[]` (from the derived graph) |
| trader loyalty | `trader_requirements[]` (`requirementType` + `compareMethod` + `value`) |
| faction | `faction` (`Any` / `Usec` / `Bear`) |
| prestige | `required_prestige` |
| other | `other_requirements[]` (e.g. `{type:"dialogue", traders:[…]}`) |

### 6.3 Objectives (1,457 rows)

Objectives are **typed**, each with its own schema, and 20 distinct types:

| type | n | what it does |
| --- | ---: | --- |
| `giveItem` | 305 | hand items to a trader |
| `visit` | 221 | be at a zone |
| `shoot` | 196 | kill with weapon/gear/range constraints |
| `findItem` | 138 | find items in raid |
| `plantItem` | 129 | place items at zones |
| `findQuestItem` | 110 | find quest items |
| `giveQuestItem` | 99 | hand quest items in |
| `extract` | 86 | leave via named exit with status |
| `mark` | 83 | mark a spot with a marker item |
| `buildWeapon` | 30 | assemble a weapon matching attributes |
| `plantQuestItem` | 13 | place quest items |
| `traderLevel`, `taskStatus`, `useItem`, `skill`, `sellItem`, `globalVariable`, `experience`, `traderStanding`, `dialogue` | ≤10 each | progression/status checks |

Objective item references were the largest unresolved set in the raw data
(15,203 objective-item rows over 3,759 distinct items); all resolve to
canonical item names. `id_names` on each objective maps every 24-hex id it
mentions to a display string, so item, trader, map and task references inside
an objective are all resolvable without re-parsing.

### 6.4 Rewards and the four unlock kinds

Reward blocks (`start_rewards`, `finish_rewards`, `failure_outcome`) can
contain: items, `trader_standing`, skill levels, achievements, customization,
and **unlocks**. Unlocks are how the progression actually opens up:

| unlock | meaning |
| --- | --- |
| `barter_unlock` | the trader starts offering a specific barter (recipe + loyalty gate) |
| `offer_unlock` | the trader starts selling/bartering a specific item at a level |
| `craft_unlock` | a hideout recipe becomes available (station + level) |
| `trader_unlock` | the trader becomes available at all (e.g. Jaeger) |
| `location_unlock` | a map/area becomes available |

So the same item can be reachable three ways — bought, bartered, crafted —
and a task can be the gate on any of them. That is why the canonical item row
records acquisition routes *and* the task that unlocks them
(`task_unlock_id` on barters and crafts, `offer_unlock` in rewards).

### 6.5 The graph

`task_leads_to` (209 edges) / `task_previous_tasks` (46) give the chain, and
`v_task_chain` flattens the forward edges. The chain is the backbone of every
playthrough order.

---

## 7. Endgame gates

- **Kappa**: 13 tasks flagged `kappa_required` must all be completed to
  obtain the Kappa secure container.
- **Lightkeeper**: 7 tasks flagged `lightkeeper_required`; the Lightkeeper
  trader and his task line are the late-game content gate.

Both flags are on the task row, so "what do I still need for Kappa" is a
single filtered query joined through `task_leads_to`.

---

## 8. Hideout

26 stations (`hideout_stations.ndjson`) with 68 levels, each level gated by
items (`hideout_level_items`), other station levels
(`hideout_level_station_reqs`) and trader loyalty
(`hideout_level_trader_reqs`). Eight of them are craft stations (§4.2); the
rest are passive upgrades (Generator, Stash, Vents, Heating, Illumination,
Security, Workbench-adjacent benches, Gym, Library, Defective Wall, …).

`found_in_raid: true` requirements matter: those items must be looted in a
raid, not bought — a hard constraint that changes how an item is valued.

---

## 9. Maps and raids

17 maps from the `maps` endpoint, 13 of which are referenced by tasks.
Each map carries `raid_duration`, `players`, `enemies`, `bosses`, `extracts`
and `transits` (map-to-map connections). Tasks bind to maps two ways: a
task-level `map_id`, and per-objective `maps[]` (many tasks span several
maps). Where a task had no task-level map, the canonical build set
`map_id` to the plurality map across its objectives, so every locatable task
has a map while the per-objective detail is preserved.

---

## 10. Reference tables

Not items but needed to interpret them:

- **player_levels** — 79 rows, level → cumulative EXP, with badge images.
- **skills** — 49 skills (each has a wiki page and is referenced by
  `skillLevelReward` and `skill` objectives).
- **mastering** — 82 weapon-mastery groups (a group lists the weapon ids that
  share mastery progress).
- **armor_materials** — 8 materials with `destructibility` and repair
  degradation bounds; this is what makes two class-4 armors behave
  differently.
- **achievements** — 123, with rarity and completion percentages.
- **flea_market / settings** — global config (scav cooldown, flea state).
- **prestige** — 6 prestige levels with conditions.

---

## 11. How the sources fit together

This is the part that is easy to get wrong. **No single offlinedata source is
complete, and the richest one has no strings at all.**

| source | contributes | does **not** have |
| --- | --- | --- |
| `tarkovdev/items.json` (5,312) | full `properties`, trade, flea stats, category ids, mod slots, `containsItems` | display names — every `name` is `<id> Name` |
| `tarkovdev/tasks.json` (517) | full task graph, typed objectives, rewards, unlocks | display names (same placeholders) |
| `tarkovdev/barters.json` (789) / `crafts.json` (214) | live offers and recipes | names |
| `tarkovunlockables/items_index.json` (3,399) | ready-made per-item `obtain_from` summary, real names | coverage — 40% of items are missing |
| `officialwiki/parsed_items.json` (3,899) | wiki titles + parsed infoboxes (raw game stat sheet), mod slots | coverage, structure is wiki-text |
| `tarkovmarket/items_all.json` (4,403 usable) | real names, market tags, market urls | prices in the bulk file (only the single-item example has them) |
| `fetched/items_en|tasks_en|traders_en|maps_en` | **all** display strings, official | nothing else |
| `fetched/maps`, `fetched/hideout` | map + hideout-station entities | names (separate `_en`) |

Consequences that shape the pipeline:

1. **Names must be fetched separately.** The saved dumps are
   localization-parameterised; without `items_en`/`tasks_en`/`traders_en` our
   export would be full of `<id> Name`. Two different endpoints are needed:
   `items_en` for the 5,312 main items, `tasks_en` for the 135 quest items,
   which `/items` does not return at all. See `docs/02_sources.md`.
2. **Only 3,399 of 5,480 items have the unlockables `obtain_from` summary**,
   so the acquisition graph is rebuilt from the raw sources (barters, crafts,
   task rewards, hideout) rather than trusted from that index — and the index
   is kept only as a cross-check. Currency purchases are deliberately *not*
   merged, because the two sources mean different things: tarkovdev's `buy`
   is a priced purchase of the item itself (2,598 items), while the index's
   `index_offers` lists trader loyalty rows, 78 of which carry a preset
   *variant* label ("SOPMOD I variant after completing …"), with no price. Keeping
   them apart gives 2,965 items with a buying route without inventing a merged
   semantic.
3. **`items_index` and the Rails DB use real names from a different
   vocabulary than the official `items_en`.** The DB's `full_name` came from
   the derived index; the canonical dataset prefers the official strings.
   Expect cosmetic differences ("M4A1 5.56x45 upper receiver" vs the official
   title for the same id).
4. **Quest items live in a side dict** and are absent from `/items`, wiki and
   market for the most part (only 10/135 have a market name, 4/135 a wiki
   name). All 135 are localized by `tasks_en` instead, so they carry
   `name_source: tarkovdev:tasks_en` — no name in the dataset is derived from
   a slug.

---

## 12. Reading order for a newcomer

1. `canonical/items.ndjson` — find an item you know; look at `acquisition`
   and `used_in`.
2. `canonical/traders.ndjson` — see the loyalty ladder.
3. `canonical/barters.ndjson` + `crafts.ndjson` — see how items are produced.
4. `canonical/tasks.ndjson` — see the gates and the unlock rewards.
5. `canonical/hideout_stations.ndjson` + `maps.ndjson` — the two progression
   surfaces.
6. `tarkov.sqlite3` — run the queries in `README.md`.
