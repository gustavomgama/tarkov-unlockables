# Canonical dataset ↔ the Rails database

The app's Postgres schema (`db/schema.rb`, version `2026_09_12_000000`) is a
normalized, item-centric **projection** of this dataset. `db:seed` truncates
its data tables and reloads them from `datastore/canonical/` through
`Importers::Datastore` (`app/services/importers/datastore.rb`): the NDJSON is
the source of truth, and the Rails schema is the subset the app renders today.

Current shape of `tarkov_db_development` after `db:seed` vs the dataset:

| | canonical | Postgres | why they differ |
| --- | ---: | ---: | --- |
| items | 5,481 | 5,481 | 1:1 on `bsg_id`. Slots, grids, `properties`, `physical` and acquisition collapse into the `data` jsonb. |
| tasks | 517 | 517 | 1:1 on `bsg_id`. Objectives and needed keys are stored; maps are denormalized and most reward kinds are dropped. |
| buy routes | 2,658 `buy` + 3,202 `index_offers` | 3,248 `item_currencies` | one row per `(trader, currency, level)`, the two sources deduped; price, `price_rub` and buy limit stored. |
| barter offers | 789 | 840 `item_barters` | one row per offer; inputs in `item_barter_requirements`, plus limit, restock and the task gate. |
| crafts | 214 | 214 `item_hideouts` | one row per craft; inputs and tools in `item_hideout_requirements`, plus duration and yield. |
| task rewards | 1,964 reward rows | 1,034 `rewards` (989 loose items, 288 offers, 98 barters, 71 crafts) | the kinds without a table ride along in `rewards.data`: 362 `trader_standing`, 136 `skill_level_reward`, 13 `customization`, 4 `achievement`, 2 `trader_unlock`, 1 `trader_dialogue_unlock`. |
| task objectives | 1,457 | 1,457 `task_objectives` (+ 1,467 `task_objective_items`) | 1:1 per objective: type, description, count, optional, source order. Accepted items live in `task_objective_items`; catch-alls with 100+ ids ("sell any items") are skipped. |
| traders | 16 | — | no table: trader names are strings (`given_by`, `trader`, …). |
| maps | 17 | — | no table: a task's map is `tasks.map_name` (13 values). |
| categories | 200 | — | no table: leaf slugs live in `items.categories`. |
| hideout stations | 26 stations / 68 levels | 26 `hideout_stations` / 68 `hideout_levels` / 317 item requirements | build costs stored, including FIR flags and station/trader gates; `item_hideouts.station` stays a string join. |
| reference | levels, skills, mastery, armor materials, achievements | — | no tables. |

---

## Mapping table

| canonical | Postgres | note |
| --- | --- | --- |
| `items` | `items` | 1:1 on `bsg_id`. Canonical `name`→`full_name`, `short_name`→`short_name`, `slug`→`slug`, `links`/`images`→arrays, `properties`+`stats`→`data` jsonb. |
| `items.slots` | — | **no table.** The DB has no mod-slot graph; the wiki `mods` block is dumped raw into `data.mods`. |
| `items.grids` | — | **no table.** Only `data` jsonb. |
| `items.contains_items` | — | **no table.** Only `data.containsItems`. |
| `items.trade.buy_from` | `item_currencies` | canonical adds `price`, `price_rub`, `buy_limit`; `task_unlock` is a bool in the DB but a task id here. |
| `items.acquisition.barter` | `item_barters` | DB: `(trader, trader_level)`. Canonical: full `required_items`/`offered_item`/limits. |
| `items.acquisition.craft` | `item_hideouts` | DB: `(station, level)`. Canonical: recipe, duration, tools. |
| `items.acquisition.task_rewards` | `item_task_rewards` | canonical adds `phase` and `count`. |
| `items.categories` | `items.categories` (string array) | DB stores leaf slugs; canonical keeps ids + paths + handbook tree. |
| `categories` | — | **no table.** The 200-node tree (internal + handbook) exists only inside item rows in the DB. |
| `traders` | — | **no table.** Traders are strings (`given_by`, `trader` columns) and `item_currencies.trader`. |
| `traders.levels` | — | **no table.** No loyalty thresholds stored, so "can I buy this yet" is unanswerable. |
| `barters` | `item_barters` (+ nothing) | canonical is a first-class entity with an id. |
| `crafts` | `item_hideouts` (+ nothing) | same. |
| `tasks` | `tasks` | 1:1 on `bsg_id`. The DB keeps `full_name`, `slug`, `trader_slug`, `wiki_link`, `map_id`/`map_name`, `experience`, `faction` and the kappa/lightkeeper flags. Canonical also has `min_player_level`, `trader_id`, `name_source`. |
| `tasks.task_requirements` | `previous_tasks` (via `requirements`) | DB has the chain; canonical also has `status`. |
| `tasks.trader_requirements` | `requirements.trader_level` (jsonb array) | DB is a loose jsonb array; canonical has requirement type + comparator + value. |
| `tasks.leads_to` | `leads_tos` | 1:1. |
| `tasks.objectives` | `task_objectives` + `task_objective_items` | 1:1 per objective (type, description, count, optional, position) and its accepted items; catch-alls (100+ ids) are skipped. |
| `tasks.start_rewards` | `rewards` (`reward_type='start_rewards'`) + `rewards.data` | 1:1; modelled kinds get tables, the rest (trader standing, skills, achievements, dialogue, customization) go to `data`. |
| `tasks.finish_rewards` | `rewards` + `rewards.data` | 1:1, same split. |
| `tasks.needed_keys` | `tasks.needed_keys` | jsonb: a flat array of `{map_name, item_id, item_name}`, grouped by map in the view. |
| `hideout_stations` + levels | `hideout_stations` + `hideout_levels` + `hideout_item_requirements` | Stations, levels, construction time and build costs. Station and trader prerequisites are jsonb on the level. |
| `maps` | `tasks.map_name` | Denormalized: only the task's map name, not extracts, bosses or transits. |
| `reference` (levels, skills, mastery, armor materials, achievements) | — | **no tables.** |

---

## What the DB still cannot answer

1. **"Can this weapon build work?"** — no slot graph, no allowed-items edges.
2. **"Which tasks unlock the Jaeger trader, or a location?"** — the 2
   `trader_unlock` and the location unlocks are dropped; offer and craft
   unlocks are stored.
3. **"What does this item's flea price say?"** — no economy or sell-to fields
   are stored; prices are out of scope for the app.
4. **"What is this category, in the handbook?"** — no `categories` table; leaf
   slugs live on `items.categories`.
5. **"What are the flea level, skills, mastery or achievements?"** — the
   `reference` tables are not imported.

---

## Recommended path if the DB should carry the richer data

Ordered by value per unit of work; nothing above is required for the dataset to
be useful on its own. The item universe is already done — `db:seed` loads all
5,481 canonical items, not the 3,399 the old index knew.

1. **Add a `traders` table** (+ `trader_levels`). Trader names are still
   strings everywhere; the maps case is handled by `tasks.map_name`.
2. **Add the item mod graph** (`item_slots`, `item_slot_allowed`) — needed
   for any gun-builder feature.
3. **Add `categories`** (with `kind`) so the taxonomy is not item-local.
4. **Widen rewards** to the full `task_rewards` shape (kind + phase +
   trader/station/skill/achievement payloads).

The canonical NDJSON maps to those tables one-to-one, and
`datastore/tarkov.sqlite3` already *is* that shape in a queryable form — it is
the reference for what the Postgres schema would look like with these
additions.
