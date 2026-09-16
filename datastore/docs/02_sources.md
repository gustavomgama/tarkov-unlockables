# Data sources, provenance and gaps

Everything the canonical dataset is built from. Two locations:

- `offlinedata/` — the saved snapshots that ship with the repo (the working
  set this task started from).
- `datastore/fetched/` — seven endpoints fetched from
  `https://json.tarkov.dev/regular` on **2026-09-16** to supply the display
  strings and reference entities the snapshots lack. Hashes and sizes in
  `fetched/manifest.json`; refresh with `scripts/10_fetch.py --refresh`.

---

## 1. offlinedata inventory

### tarkovdev — the game API, unlocalized

`https://json.tarkov.dev/regular` (open JSON API, no auth). Saved
**2026-08-25 / 2026-09-03**.

| file | bytes | real payload |
| --- | ---: | --- |
| `items.json` | 25.8 MB | `data = {items: 5312, itemCategories: 112, handbookCategories: 88, fleaMarket, armorMaterials, playerLevels: 79, mastering: 82, skills: 49, specialItems: 37, settings}` |
| `tasks.json` | 4.0 MB | `data = {tasks: 517, questItems: 135, achievements: 123, prestige: 6}` |
| `barters.json` | 532 KB | 789 barter offers |
| `crafts.json` | 223 KB | 214 hideout recipes |
| `traders.json` | 74 KB | 16 traders keyed by raw id |
| `wiki_titles_pipe_separated.txt` | 130 KB | wiki page titles used by the wiki crawler |
| `itemexample.json` | 11 KB | one pruned item, kept as a shape reference |

**Critical caveat:** this snapshot is localization-parameterised. Every
`name` value is the literal string `<bsgId> Name` (5,311 of 5,312 items), every
task name is `<id> name`, and every `translations` array is empty — it lists
the JSONPath selectors that *would* be translated, not translated values. The
included `README.md` describes a *pruned* response shape that does not match
the saved bytes (it claims `data` is keyed by item id; it claims trader refs
are normalized — only barter/task refs are). Counts in it are stale
(documented 443 barters vs 789 actual). Trust the bytes, not that README.

### tarkovunlockables — derived per-item unlock index

Pre-computed from the two sources above, with **real names**. This is what the
Rails app's `db/seeds.rb` imports.

| file | rows | notes |
| --- | ---: | --- |
| `items_index.json` | 3,399 | `slug/full_name/short_name/links/images/properties/obtain_from/categories/bsg_id` |
| `tasks_index.json` | 519 | 52 rows have a blank `bsg_id` and are unusable as keys |
| `traders_index.json` | 10 | real trader names, only the classic traders |
| `buyables_index.json` | 3,202 | flat currency-buy list |
| `barteables_index.json` / `barter_index.json` | 443 | flat barter list (superseded by 789 raw barters) |
| `craftables_index.json` / `craft_index.json` | 8 stations | flat craft list |
| `task_gated_buyables.json` | 119 | task → offer unlocks |
| `task_gated_barters.json` | 45 | task → barter unlocks |
| `task_gated_crafts.json` | 34 | task → craft unlocks |

The wiki's `barter_list.json` / `craft_list.json` are name-only and lag the
live API; they are used strictly as corroboration (`70_crosscheck.py`): 85% of
its 443 trade rows and 93% of its 213 craft outputs match a canonical route,
matching by (normalized trader, normalized item name). The wiki-only residuals
are listed in `reports/08_wiki_crosscheck.md` rather than dropped.

The wiki is also the dataset's only **numeric** cross-check. Its item infoboxes
carry ballistics in the same units as the game (`damage`, `penetration`,
`armor_damage`, `velocity`, `ricochet`, `accuracy`, `recoil`,
`durability_burn`, `heat`), which the API exposes as `item.properties`. After
unit conversion (the API stores accuracy/recoil as fractions and
durability/heat as `1+factor`) and the wiki's 1-decimal rounding, **1,510 of
1,522 values agree (99%)**. The 12 that do not are listed in
`reports/08_wiki_crosscheck.md`; they are mostly stale wiki rows (M61 ricochet
30% vs 25%) plus a cluster on 20/70 shells where the wiki's heat and damage are
systematically higher.

The join between the wiki and the API items is the infobox **`node` id**, not
the page title. The title can disagree with the API's item name — 22 of the
4,115 covered items (0.5%) do, e.g. the page "AWC PSR .338 LM muzzle brake"
whose single `node` is the item the API calls "SilencerCo AC-858 ASR .338 LM
muzzle brake". A handful of pages also group two ids (the "Locked case" page
lists both the locked and the opened case); those items share one infobox in
the wiki itself, so the shared page is faithful rather than a misattachment.
`99_verify` bounds the disagreement so it cannot grow into real misattachment.

`obtain_from` per item is `{task_rewards, hideout, barter, currency}`. Useful
as a ready-made summary and as a **cross-check**, but it only covers 3,399
items (62% of the universe) and its `hideout` entries are crafts, so the
canonical build recomputes acquisition from raw sources instead.

One thing it carries that the raw API does **not** is `barter_unlocks` in
`tasks_index.json` — `/regular/tasks` exposes no `barterUnlock` reward, so
task-gated barter recipes (45 items, 13 of them in no tarkovdev barter) exist
only here. Those are merged into `tasks.ndjson` reward blocks and into
`items.ndjson` acquisition routes, tagged `source: tarkovunlockables`.

### tarkovmarket — names, tags, market links

`https://api.tarkov-market.app/api/v1` (API key in `x-api-key`).
`items_all.json`: 4,565 records, 4,403 distinct non-empty `bsgId` (duplicates
exist — pick the first). Only 10 fields: `uid, bsgId, name, shortName, tags,
icon, img, imgBig, link, wikiLink`.

**The bulk file has no prices.** `avg24hPrice`, `basePrice`, `traderPriceRub`,
`bannedOnFlea`, `haveMarketData` etc. exist only in `item.json`, the saved
single-item example (`/item?q=...`). So market price data is not available
offline; the price fields in the canonical dataset come from tarkovdev.
`.gitignore` excludes this directory (the dump embeds a key), so it is a
local-only snapshot — `datastore/` reads it when present.

### officialwiki — parsed wiki content

Fandom wiki (`escapefromtarkov.fandom.com`).

| file | bytes | contents |
| --- | ---: | --- |
| `parsed_items.json` | 4.3 MB | 3,899 items keyed by BSG id: `full_name` (wiki page title) + parsed `infobox` (19 keys) + `sections.mods` / `sections.weapon_variants`. 156 of those pages name **several** node ids (colour variants, ammo packs, PvE/PvP twins); `20_build_canonical.py` re-parses `itembatches/` and clones the page onto the 216 sibling ids, taking wiki coverage to 4,115 items |
| `all_wiki_content.wiki` | 8.9 MB | raw wikitext dump |
| `filtered_wiki_content_normalized.wiki` | 3.3 MB | filtered/normalized variant |
| `tasks.wiki` | 301 KB | per-quest wiki pages with reward/reputation/chain fields |
| `quest_list.wiki` | 243 KB | quest index page |
| `barter_list.json` / `.wiki` | 183 KB / 144 KB | 443 wiki-parsed barters (names only, no ids) |
| `craft_list.json` / `.wiki` | 122 KB / 116 KB | 8 stations of wiki-parsed crafts (names only) |
| `wiki_items_not_in_items_index.wiki` | 21 KB | 152 items with trader data but missing from the unlockables index — a documented gap |
| `itembatches/` | 11 MB | 85 MediaWiki API batches, 3,936 pages — the raw crawl behind `parsed_items.json` |

The wiki also names weapon builds per base weapon (`sections.weapon_variants`,
102 builds over 51 weapons with their full attachment lists); each maps 1:1 to
a tarkovdev preset except `Glock 17 HC`, which has no preset.

The wiki infobox also supplies an internal game id (`ID`, 2,784 items),
loot/examine XP (674), a handbook price (651) and a hand-maintained trader
loyalty list (`trader`, 2,371 items → 2,536 parsed offers), all of which are
exposed on the canonical item record.

The wiki infobox is the raw in-game stat sheet (`trader`, `ergonomics`,
`recoil`, `MOA`, `caliber`, `damage`, `penetration`, `armor`, `durability`,
`loot_xp`, `exam_xp`, …). It is 1:1 complementary to `properties`: richer in
some fields (XP values, `trader` loyalty text), weaker in others (stringly
typed, wiki-markup links). Kept verbatim as `wiki.infobox`.

---

## 2. Fetched endpoints (`datastore/fetched/`)

| endpoint | bytes | why |
| --- | ---: | --- |
| `items_en` | 1.65 MB | 16,460 keys: `<id> Name` (5,821), `<id> ShortName` (5,344), `<id> Description` (4,835), plus slot/zone names (`MOD_PISTOL_GRIP` → "Pistol Grip"). **The main display-name layer.** Does *not* cover quest items. |
| `tasks_en` | 249 KB | 3,645 keys: `"<id> name"` → quest name, objective ids → description, **and `"<id> Name"/"<id> ShortName"/"<id> Description"` for all 135 quest items**, which `/items` omits. |
| `traders_en` | 3.5 KB | 32 keys: `"<id> Nickname"` / `"<id> Description"` |
| `maps_en` | 23 KB | 424 keys: `"<id> Name"` → map name |
| `maps` | 8.6 MB | 17 map entities: `raidDuration`, `players`, `enemies`, `bosses`, `extracts`, `transits` |
| `hideout` | 80 KB | 26 stations, 68 levels, with `itemRequirements` (incl. `foundInRaid`), `stationLevelRequirements`, `traderRequirements`, `constructionTime` |
| `hideout_en` | 15 KB | `hideout_area_N_name` → station name |

These are live endpoints, so the canonical build is **snapshot + live
localization**. Ids are stable across both; the 2026-09-03 snapshot had 5,312
items and the 2026-09-16 live build had 5,320, so a handful of newest items
are absent from the snapshot (and hence from the canonical dataset by design —
the task scopes the universe to `offlinedata`).

---

## 3. What is missing / known gaps

Ranked by how likely it is to matter:

1. ~~No localization for quest items.~~ **Resolved.** `items_en` has no entry
   for the 135 quest items and `/items` does not include them, but `tasks_en`
   localizes every one of them (`<id> Name` / `ShortName` / `Description`), so
   the build reads it as a second name source. No item in the dataset falls
   back to a slug-derived name.
2. **No bulk flea prices from tarkov-market.** `items_all.json` has no price
   fields; only the single-item example does. Prices in the dataset are
   tarkovdev's (`avg24h_price` etc.), which are current-ish but a few fields
   differ from tarkov-market's model (`basePrice`, `traderPriceRub`,
   `bannedOnFlea`, `haveMarketData`, `diff24h`).
3. **152 items exist on the wiki with trader data but are absent from
   `items_index`** (`wiki_items_not_in_items_index.wiki`). Our universe covers
   them via tarkovdev; the list is useful as a regression guard.
4. **`traders_index.json` only knows 10 of 16 traders** — the six newer
   entities (`taran`, `radio-station`, `btr-driver`, `mr-kerman`, `voevoda`,
   `survivor`) have no name there; `traders_en` covers them.
5. **`tasks_index.json` has 52 blank-`bsg_id` rows.** Dropped; they cannot be
   joined. Their content (if any) is not in the canonical dataset.
6. **No localization for tarkov-market's `tags`** — they are already english
   labels, kept as-is.
7. **`item.json`'s price fields are a single sample**, not a snapshot; do not
   treat as current.

---

## 4. Attribution / licensing

- **tarkov.dev** — open data project, data derived from the game; the JSON API
  is public and unauthenticated. Offline snapshot + live endpoints both used.
- **tarkov-market.app** — commercial API; `x-api-key` required, rate limited
  (300 req/min, 5 req/min for bulk). Snapshot gitignored because it embeds a
  key.
- **Escape from Tarkov Wiki (Fandom)** — community content, CC BY-SA unless
  otherwise noted. Scraped/parsed dumps only.
- **Escape from Tarkov** — IP of Battlestate Games. Nothing here redistributes
  game assets; image URLs are hotlinks to the sources' CDNs, not copies.
