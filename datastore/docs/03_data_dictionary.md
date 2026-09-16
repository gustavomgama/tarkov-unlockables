# Data dictionary

One record per line (NDJSON) per file in `canonical/`, except
`reference.json`. Optional fields are `null`/`[]`/`{}` when the source lacks
them; nothing is invented. Every item reference (`bsg_id` + `name`) is a
denormalized convenience — the `bsg_id` is the join key.

---

## `items.ndjson` — 5,481 rows

| field | type | notes |
| --- | --- | --- |
| `bsg_id` | string | primary key, 24-hex |
| `slug` | string | tarkovdev `normalizedName`; falls back to the unlockables index |
| `name` | string | resolved display name (see `name_source`) |
| `short_name` | string? | inventory label |
| `description` | string? | official flavour text (4,835 available) |
| `name_source` | string | `tarkovdev:items_en` (5,312) \| `tarkovdev:tasks_en` (135 quest items) \| `tarkovmarket` (33). No name is derived from a slug. |
| `quest_item` | bool | only exists as a quest hand-in/plant item |
| `types` | string[] | game-facing tags/flags (`mods`, `noFlea`, `preset`, `ammoBox`, …) |
| `categories` | object | `{ids, leaves, paths}` from the internal category tree |
| `handbook_categories` | object | `{ids, leaves, paths}` from the player-facing handbook tree |
| `properties_type` | string? | one of 28 `ItemProperties*` schemas |
| `properties` | object | **verbatim** type-specific block |
| `stats` | object | the flattened stat keys tarkov.dev repeats at top level (kept because `properties` is absent for some kinds) |
| `slots` | object[] | resolved mod slots: `{id, name_id, name, required, filters:{allowed_items, allowed_categories, excluded_items, excluded_categories}}` |
| `grids` | object[] | storage grids: `{width, height, allowed_categories, allowed_items, excluded_categories}` |
| `physical` | object | `{width, height, weight, stack_max_size, has_grid, background_color, discard_limit}` |
| `economy` | object | `{base_price, last_low_price, avg24h_price, low24h_price, high24h_price, change_last_48h, change_last_48h_percent, last_offer_count, min_level_for_flea, last_scan}` |
| `trade` | object | `{buy_from[], sell_to[]}` → `{trader_id, trader_slug, price, price_rub, currency, currency_item, min_trader_level, task_unlock_id, buy_limit}` |
| `contains_items` | object[] | default contents of a container/preset: `{bsg_id, name, count}` |
| `conflicts` | object | `{items[], slot_ids[], categories[], wiki_items[]}` — items/slots this cannot coexist with; `wiki_items` are the wiki-sourced relations, `{bsg_id, name}` |
| `compatibility` | object[] | `{bsg_id, name}` — the wiki's "Compatibility" field: the base weapon(s) this mod is made for (9,131 relations over 1,645 items), an independent view of the mod graph |
| `images` | object | `{icon, grid, base, inspect, image512, image8x, market, market_big}` |
| `links` | object | `{tarkovdev, wiki, market}` |
| `wiki` | object? | `{title, internal_id, xp, price, trader_offers, infobox, mod_slots, weapon_variants}` |
| `wiki.internal_id` | string? | the game's own internal id (2,784 items, e.g. `weapon_colt_m4a1_556x45`) |
| `wiki.xp` | object | `{loot_xp, exam_xp}` — XP for looting / examining (674 items) |
| `wiki.price` | int? | handbook price as printed by the wiki (651 items) |
| `wiki.trader_offers` | object[] | the wiki's independent seller list: `{trader_name, trader_slug, level, level_number, variant, faction}` (2,536 offers over 2,371 items; 206 name a preset variant) |
| `market` | object? | `{uid, tags[], name, short_name}` from tarkov-market |
| `acquisition` | object | `{buy[], index_offers[], barter[], craft[], task_rewards[]}` |
| `used_in` | object | `{crafts[], barters[], hideout_build[], task_objectives[]}` |
| `sources` | string[] | which of the four offlinedata sources contained this id |

### `acquisition` and `used_in` entry shapes

```
buy[]          tarkovdev currency purchases:
               {trader_id, trader_slug, currency, min_trader_level, price, price_rub,
                task_unlock_id, buy_limit, source: "tarkovdev"}
index_offers[] the derived index's currency claims, kept separate because they
               describe preset *variants* and are broader but unpriced:
               {trader_slug, currency, level, variant, source: "tarkovunlockables"}
barter[]       {barter_id, trader_slug, min_trader_level, buy_limit, restock_amount,
                task_unlock_id, task_name, offered:{bsg_id,name,count},
                required:[{bsg_id,name,count}], source}
                source = tarkovdev (789) | tarkovunlockables (51 task-gated recipes
                that /regular/tasks does not expose at all)

`used_in.barters[]` carries the same rows **from both sources**, so 86 of 1,148
have `barter_id: null` (the index-sourced ones). Filter on `source` or on a
non-null `barter_id` when joining back to `barters.ndjson`.
craft[]        {craft_id, station_id, station_name, level, duration, task_unlock_id,
                task_name, product:{bsg_id,name,count},
                required:[{bsg_id,name,count,is_tool}], source: "tarkovdev"}
task_rewards[] {task_id, task_name, phase, count}          phase = start | finish
hideout_build  {station_id, station_name, level, count, found_in_raid}
task_objectives{task_id, task_name, type}
```

---

## `weapon_variants.ndjson` — 102 rows

Named weapon builds from the wiki's `weapon_variants` sections, keyed by the
base weapon.

| field | type | notes |
| --- | --- | --- |
| `base_bsg_id`, `base_name` | string | the weapon the build starts from (51 distinct) |
| `name` | string | the build's name, e.g. `AS VAL Kobra` |
| `attachments` | object[] | `{bsg_id, name}` — the exact parts in the build (1,043 total) |
| `preset_bsg_id`, `preset_slug` | string? | the tarkovdev preset this names, when one exists (101 of 102, 1:1) |

`v_weapon_variant_attachments` resolves each part; `v_item_armor` joins
armored items to the 8 armor materials so `destructibility` /
repair-degradation bounds sit next to `class` and `durability`.

## `tasks.ndjson` — 517 rows

| field | type | notes |
| --- | --- | --- |
| `id` | string | BSG task id |
| `slug` | string | `normalizedName` |
| `name`, `name_source` | string | from `tasks_en`, else the derived index, else the wiki link |
| `wiki_link` | string | fandom quest page |
| `trader_id`, `trader_slug`, `trader_name` | string | exactly one giver |
| `map_id`, `map_name` | string? | task-level map, else the plurality map across objectives |
| `min_player_level`, `experience` | int | |
| `faction` | string | `Any` \| `Usec` \| `Bear` |
| `kappa_required`, `lightkeeper_required`, `restartable` | bool | endgame flags |
| `required_prestige`, `game_mode[]` | | prestige/DLC gating |
| `available_delay_seconds` | object | `{min, max}` before the task becomes available |
| `task_requirements` | object[] | `{bsg_id, name}` — prerequisite tasks |
| `trader_requirements` | object[] | `{trader_id, trader_slug, requirement_type, compare_method, value}` |
| `other_requirements` | object[] | raw, e.g. `{type:"dialogue", traders:[…]}` |
| `objectives` | object[] | see below |
| `fail_conditions` | object[] | raw |
| `needed_keys` | object[] | `{map_id, map_name, keys:[{bsg_id,name}]}` |
| `start_rewards` / `finish_rewards` / `failure_outcome` | object | see below |
| `leads_to` | object[] | `{task_id, task_name}` (from the derived graph) |
| `previous_tasks` | string[] | task ids |
| `task_image_url` | string | |

### objective shape

```
{id, type, description, optional, count,
 raw: <the untouched tarkovdev objective>,
 id_names: { "<24-hex id>": "<display string>" }}
```

`id_names` covers every item/trader/map/task id mentioned anywhere inside the
objective, so you can resolve `raw` without a second lookup. `description`
comes from `tasks_en[objective_id]`.

### reward block shape

```
items[]                 {bsg_id, name, count, attributes}
barter_unlock[]         {barter_id, trader_slug, min_trader_level, buy_limit,
                        restock_amount, task_unlock_id, offered:{bsg_id,name,count},
                        required:[{bsg_id,name,count}], source, phase}
                        tarkovdev has no barterUnlock reward, so most entries here
                        come from the derived index; a tarkovdev barter that names
                        this task in `taskUnlock` contributes its recipe.
trader_standing[]       {trader_id, trader_slug, standing}
offer_unlock[]          {bsg_id, name, count, unlock_id, trader_id, trader_slug, level, source}
craft_unlock[]          {bsg_id, name, count, station_id, station_name, level, source}
trader_unlock[]         {trader_id, trader_slug, trader_name}
skill_level_reward[]    {skill, level}
achievement[]           {id, name}
customization[]         {id, customizationType}
location_unlock[]       {map_id, map_name}
trader_dialogue_unlock[] {trader_id, trader_slug}
```

---

## `traders.ndjson` — 16 rows

`id, slug, name, description, currency, reset_time, discount, image_url,
task_count, levels[], reputation_levels[], buy_allowed{categories,items},
buy_prohibited{categories,items}`.

`levels[]`: `{id, level, required_player_level, required_reputation,
required_commerce, pay_rate, insurance_rate, repair_cost_multiplier}`.

---

## `barters.ndjson` — 789 rows

`id, trader_id, trader_slug, trader_name, min_trader_level, buy_limit,
restock_amount, task_unlock_id, task_unlock_name, offered_item{bsg_id,name,count},
required_items[{bsg_id,name,count,attributes}]`.

## `crafts.ndjson` — 214 rows

`id, station_id, station_slug, station_name, level, duration, duration_seconds,
game_editions[], task_unlock_id, task_unlock_name, product_item{bsg_id,name,count},
required_items[{bsg_id,name,count,is_tool}], required_quest_items[…]`.

## `hideout_stations.ndjson` — 26 rows

`id, slug, name, area_type, image_url, levels[]` where each level is
`{id, level, construction_time, item_requirements[{bsg_id,name,count,found_in_raid}],
station_level_requirements[{station_id,station_name,level}],
trader_requirements[{trader_id,trader_slug,level}]}`.

## `maps.ndjson` — 17 rows

`id, slug, name, name_id, wiki_link, description, raid_duration, players,
enemies[], bosses[], extracts[{name,faction}], transits[{name,map}]`.

## `categories.ndjson` — 200 rows

`id, kind` (`item` \| `handbook`), `slug, parent_id, children_ids, path, depth,
min_level_for_flea, image_url`. `path` is the full slug chain from the root.

## `reference.json`

`flea_market, armor_materials, player_levels, skills, mastering, special_items,
settings, prestige, achievements[], generated_from`.

`special_items` entries are `{id, kind, name}` with `kind = item | category`.
The API's raw `specialItems` mixes the two: 28 item ids plus the 9 categories
that group special-slot items (compass, portable range finder, radio
transmitter, map, multitools, planting kits, recorder, cultist amulet, mark of
the unheard). Joining the raw id list to `items` silently drops the 9 category
rows. The authoritative signal for "this item fits the special slot" is
`types` containing `specialSlot` (44 items) — every category member is already
typed that way.

`mastering[]` holds `{id, weapons[], level2, level3}`; all 159 referenced
weapon ids resolve to items.

---

## `tarkov.sqlite3`

41 tables + 3 views + an FTS5 index built from the files above. The NDJSON nests are
normalized: `item_slots` / `item_slot_allowed` (mod graph),
`item_trade`, `item_acquisition`, `item_used_in`, `task_objectives` /
`task_objective_items` / `task_objective_refs`, `task_rewards`,
`hideout_level_*`, `item_grids`.

Useful views:

- `v_item_price` — item + flea price + best trader sell / buy in one row.
- `v_item_acquisition` — flattened acquisition routes joined to item names.
- `v_task_chain` — forward task edges with both names.

`item_wiki_meta` carries `internal_id`/`price`/`loot_xp`/`exam_xp`;
`item_wiki_trader_offers` carries the parsed wiki seller list.

`item_acquisition.route` holds `buy` (tarkovdev), `buy_index` (the derived
index's unpriced offers), `barter`, `craft` and `task_reward` (`task_reward`
rows include the `barter_unlock` kind); `item_used_in.route`
holds `craft`, `barter`, `hideout_build` and `task_objective`.

`conflicts` merges two sources without overwriting either: the API's
`items`/`slot_ids`/`categories` (11,312 / 21 / 1 relations) verbatim, plus
`wiki_items` from the wiki's "Conflicting items" section (2,246 relations over
242 items — 2,054 corroborating the API, 192 wiki-only). `conflictingSlotIds`
and `conflictingCategories` are near-unused upstream, which is real, not a
parsing gap.

`items_fts` is an FTS5 index over `name`, `short_name`, `slug`
(`unicode61 remove_diacritics 2`), queried with
`SELECT * FROM items_fts WHERE items_fts MATCH 'ledx'`.
