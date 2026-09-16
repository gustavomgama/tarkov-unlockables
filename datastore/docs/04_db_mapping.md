# Canonical dataset ↔ the Rails database

The app's Postgres schema (`db/schema.rb`, version `2026_09_12_000000`) is a
normalized, item-centric **projection** of this dataset. `db:seed` truncates
its data tables and reloads them from `datastore/canonical/` through
`Importers::Datastore` (`app/services/importers/datastore.rb`): the NDJSON is
the source of truth, and the Rails schema is the subset the app renders today.

Current shape of `tarkov_db_development` after `db:seed` vs the dataset:

| | canonical | Postgres | why they differ |
| --- | ---: | ---: | --- |
| items | 5,481 | 5,481 | 1:1 on `bsg_id`. Slots, grids, `properties` and acquisition collapse into the `data` jsonb. |
| tasks | 517 | 517 | 1:1 on `bsg_id`. Objectives are stored; maps, needed keys and most reward kinds are dropped. |
| buy routes | 2,658 `buy` + 3,202 `index_offers` | 3,248 `item_currencies` | one row per `(trader, currency, level)`, the two sources deduped; price, `price_rub` and buy limit stored. |
| barter offers | 789 | 840 `item_barters` | one row per offer; inputs in `item_barter_requirements`, plus limit, restock and the task gate. |
| crafts | 214 | 214 `item_hideouts` | one row per craft; inputs and tools in `item_hideout_requirements`, plus duration and yield. |
| task rewards | 1,964 reward rows | 1,034 `rewards` (989 loose items, 288 offers, 98 barters, 71 crafts) | the kinds without a DB column are dropped: 362 `trader_standing`, 136 `skill_level_reward`, 13 `customization`, 4 `achievement`, 2 `trader_unlock`, 1 `trader_dialogue_unlock`. |
| task objectives | 1,457 | 1,457 `task_objectives` (+ 1,467 `task_objective_items`) | 1:1 per objective: type, description, count, optional, source order. Accepted items live in `task_objective_items`; catch-alls with 100+ ids ("sell any items") are skipped. |
| traders | 16 | — | no table: trader names are strings (`given_by`, `trader`, …). |
| maps | 17 | — | no table: a task's map is `tasks.map_name` (13 values). |
| categories | 200 | — | no table: leaf slugs live in `items.categories`. |
| hideout stations | 26 stations / 68 levels | — | no table: station names are strings on `item_hideouts`. |
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
| `tasks` | `tasks` | 1:1 on `bsg_id`. The DB keeps `full_name`, `slug`, `trader_slug`, `wiki_link` and the kappa/lightkeeper flags. Canonical also has `map_id`, `min_player_level`, `experience`, `faction`, `trader_id`, `name_source`. |
| `tasks.task_requirements` | `previous_tasks` (via `requirements`) | DB has the chain; canonical also has `status`. |
| `tasks.trader_requirements` | `requirements.trader_level` (jsonb array) | DB is a loose jsonb array; canonical has requirement type + comparator + value. |
| `tasks.leads_to` | `leads_tos` | 1:1. |
| `tasks.objectives` | `task_objectives` + `task_objective_items` | 1:1 per objective (type, description, count, optional, position) and its accepted items; catch-alls (100+ ids) are skipped. |
| `tasks.start_rewards` | `rewards` (`reward_type='start_rewards'`) | 1:1, plus the kinds the DB drops (trader unlocks, skills, achievements, dialogue, customization). |
| `tasks.finish_rewards` | `rewards` | 1:1. |
| `tasks.needed_keys` | — | **no table.** |
| `hideout_stations` + levels | — | **no table.** Station names exist only as strings on `item_hideouts`. Hideout build requirements (items, FIR flags, station prerequisites) are absent. |
| `maps` | `tasks.map_name` | Denormalized: only the task's map name, not extracts, bosses or transits. |
| `reference` (levels, skills, mastery, armor materials, achievements) | — | **no tables.** |

---

## What the DB cannot answer today

These are the concrete capabilities the canonical dataset adds, phrased as
queries the Postgres schema cannot express:

1. **"How do I get item X?"** — the DB can list a trader name per item but not
   the barter recipe, craft recipe, task unlock, or the loyalty/hideout/quest
   gates on each route.
2. **"What is item X used for?"** — nothing in the DB tracks reverse usage
   (craft inputs, barter requirements, hideout build costs, objective
   hand-ins). 3,878 of the 5,481 items have at least one `used_in` route here.
3. **"Can this weapon build work?"** — no slot graph, no allowed-items edges.
4. **"What do I have to do for task T?"** — objectives and their accepted
   items are stored; only needed keys are absent.
5. **"Which tasks unlock the Jaeger trader / this craft / this offer?"** —
   `offer_unlocks` (288) and `craft_unlocks` (71) exist, but the 2
   `trader_unlock` and location unlocks are dropped.
6. **"Where does this task happen?"** — no map data at all.
7. **"How much does it cost to build the Lavatory?"** — no hideout
   requirements.

---

## Recommended path if the DB should carry the richer data

Ordered by value per unit of work; nothing above is required for the dataset to
be useful on its own. The item universe is already done — `db:seed` loads all
5,481 canonical items, not the 3,399 the old index knew.

1. **Add the two missing first-class tables**: `traders` (+ `trader_levels`)
   and `maps`. They are small wins that make existing string columns
   relational.
2. **Add the item mod graph** (`item_slots`, `item_slot_allowed`) — needed
   for any gun-builder feature.
3. **Add `hideout_stations` + level requirements**, and **`categories`**
   (with `kind`) so the taxonomy is not item-local.
4. **Widen rewards** to the full `task_rewards` shape (kind + phase +
   trader/station/skill/achievement payloads).

The canonical NDJSON maps to those tables one-to-one, and
`datastore/tarkov.sqlite3` already *is* that shape in a queryable form — it is
the reference for what the Postgres schema would look like with these
additions.
