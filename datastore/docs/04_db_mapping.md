# Canonical dataset ↔ the Rails database

The app's Postgres schema (`db/schema.rb`, version `2026_09_12_000000`) is a
normalized, item-centric view of the same domain. It is **populated from
`offlinedata/tarkovunlockables/items_index.json` + `tarkovdev/items.json` +
`officialwiki/parsed_items.json` + `tarkovunlockables/tasks_index.json`**
(`db/seeds.rb` → `Importers::Index` → `Importers::TarkovDev` →
`Importers::Wiki` → `Importers::TaskGraph`).

Current live shape of `tarkov_db_development` vs this dataset:

| | Postgres (dev) | canonical | why they differ |
| --- | ---: | ---: | --- |
| items | 3,399 | 5,480 | the DB only creates rows present in `items_index`; `TarkovDev`/`Wiki` only *enrich* existing rows (`Item.find_by`, never create). ~1,950 mods/presets/ammo-packs and 135 quest items are absent. |
| tasks | 468 | 517 | `TaskGraph` skips the 52 blank-`bsg_id` rows in `tasks_index`; the other gap is the canonical task set being the tarkovdev one. |
| item_currencies | 3,351 | 2,965 buy routes | both derived, different sources (`obtain_from.currency` vs `buyFromTrader`). |
| item_barters | 305 | 713 barter items / 789 barters | `items_index.obtain_from.barter` records *that* an item is barterable; the canonical barters carry the full recipe. |
| item_hideouts | 188 | 184 craft items / 214 crafts | `obtain_from.hideout` is the craft list; canonical has recipes, durations, tools. |
| item_task_rewards | 443 | 392 reward items / 989 reward rows | index only knows "given by task X"; canonical knows phase + count. |
| rewards / loose_items / offer_unlocks / barter_unlocks / craft_unlocks | 936 / … / 134 / 52 / 36 | 1,732 reward rows | the DB's task-reward graph comes from `tasks_index`; canonical from tarkovdev, which includes trader unlocks, skill rewards, achievements and dialogue unlocks. |

---

## Mapping table

| canonical | Postgres | note |
| --- | --- | --- |
| `items` | `items` | 1:1 on `bsg_id`. Canonical `name`→`full_name`, `short_name`→`short_name`, `slug`→`slug`, `links`/`images`→arrays, `properties`+`stats`→`data` jsonb. |
| `items.slots` | — | **no table.** The DB has no mod-slot graph; the wiki `mods` block is dumped raw into `data.mods`. |
| `items.grids` | — | **no table.** Only `data` jsonb. |
| `items.contains_items` | — | **no table.** Only `data.containsItems`. |
| `items.trade.buy_from` | `item_currencies` | canonical adds `price`, `price_rub`, `buy_limit`; `task_unlock` is a bool in the DB but a task id here. |
| `items.trade.sell_to` | `item_barters` (misused) | the DB stores barter *traders* in `item_barters`, not barter recipes. |
| `items.acquisition.barter` | `item_barters` | DB: `(trader, trader_level)`. Canonical: full `required_items`/`offered_item`/limits. |
| `items.acquisition.craft` | `item_hideouts` | DB: `(station, level)`. Canonical: recipe, duration, tools. |
| `items.acquisition.task_rewards` | `item_task_rewards` | canonical adds `phase` and `count`. |
| `items.categories` | `items.categories` (string array) | DB stores leaf slugs; canonical keeps ids + paths + handbook tree. |
| `categories` | — | **no table.** The 200-node tree (internal + handbook) exists only inside item rows in the DB. |
| `traders` | — | **no table.** Traders are strings (`given_by`, `trader` columns) and `item_currencies.trader`. |
| `traders.levels` | — | **no table.** No loyalty thresholds stored, so "can I buy this yet" is unanswerable. |
| `barters` | `item_barters` (+ nothing) | canonical is a first-class entity with an id. |
| `crafts` | `item_hideouts` (+ nothing) | same. |
| `tasks` | `tasks` | 1:1 on `bsg_id`. Canonical adds `map_id`, `min_player_level`, `experience`, `faction`, `trader_id`, `name_source`, `wiki_link`. |
| `tasks.task_requirements` | `previous_tasks` (via `requirements`) | DB has the chain; canonical also has `status`. |
| `tasks.trader_requirements` | `requirements.trader_level` (jsonb array) | DB is a loose jsonb array; canonical has requirement type + comparator + value. |
| `tasks.leads_to` | `leads_tos` | 1:1. |
| `tasks.objectives` | — | **no table.** 1,457 objectives with item references are absent from the DB entirely. |
| `tasks.start_rewards` | `rewards` (`reward_type='start_rewards'`) | 1:1, plus the kinds the DB drops (trader unlocks, skills, achievements, dialogue, customization). |
| `tasks.finish_rewards` | `rewards` | 1:1. |
| `tasks.needed_keys` | — | **no table.** |
| `hideout_stations` + levels | — | **no table.** Station names exist only as strings on `item_hideouts`. Hideout build requirements (items, FIR flags, station prerequisites) are absent. |
| `maps` | — | **no table.** Task `map` is not stored at all. |
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
   hand-ins). 3,878 of the 5,480 items have at least one `used_in` route here.
3. **"Can this weapon build work?"** — no slot graph, no allowed-items edges.
4. **"What are the requirements of task T?"** — objectives, needed keys and
   trader-loyalty requirements are all absent; only level + previous tasks
   survive.
5. **"Which tasks unlock the Jaeger trader / this craft / this offer?"** —
   `offer_unlocks` (134) and `craft_unlocks` (36) exist but trader unlocks
   (`trader_unlock`) and location unlocks are dropped.
6. **"Where does this task happen?"** — no map data at all.
7. **"How much does it cost to build the Lavatory?"** — no hideout
   requirements.

---

## Recommended path if the DB should carry the richer data

Ordered by value per unit of work; nothing is required for this dataset to be
useful on its own.

1. **Switch the item universe to tarkovdev** (upsert instead of
   `find_by`-only in `Importers::TarkovDev`). That alone takes items from
   3,399 → 5,312 and brings presets/mods/ammo-packs in. Prefer
   `items_en` names over the merged index/wiki name to stop the three-way
   vocabulary drift.
2. **Add the two missing first-class tables**: `traders` (+ `trader_levels`)
   and `maps`. They are small wins that make existing string columns
   relational.
3. **Promote objectives to a table** (`task_objectives` +
   `task_objective_items`). Currently the single biggest blind spot for any
   "what do I have to do" feature.
4. **Add the item mod graph** (`item_slots`, `item_slot_allowed`) — needed
   for any gun-builder feature.
5. **Add `hideout_stations` + level requirements**, and **`categories`**
   (with `kind`) so the taxonomy is not item-local.
6. **Widen rewards** to the full `task_rewards` shape (kind + phase +
   trader/station/skill/achievement payloads).

The canonical NDJSON maps to those tables one-to-one, and
`datastore/tarkov.sqlite3` already *is* that shape in a queryable form — it is
the reference for what the Postgres schema would look like with these
additions.
