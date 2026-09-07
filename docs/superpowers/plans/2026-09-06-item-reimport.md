# Item Data Re-import Plan (Schema from Scratch)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the item data architecture from scratch and re-import ALL item data from `offlinedata/` (officialwiki as truth, `bsg_id` matching-only, namespaced STI type classes + JSONB `data`), fixing the constraint/idempotency problems that made the 119-item deletion irreversible, restoring those items, and adding type-specific behavior plus full admin edit capability.

**This is a FULL DO-OVER, starting with items:** every existing migration and every existing model is deleted and recreated from scratch. Nothing from the old schema survives. The new schema is built in two migrations (items + full task graph) and every model is written fresh.

**Architecture:** Single `items` table with STI (`type` column) + JSONB `data` column. 10 namespaced type classes (`Item::Weapon`, `Item::Ammo`, ...). Obtain graph as 4 child tables FK'd to `items.id`. Importers merge 4 sources in order: index → tarkovdev → market → wiki (wiki wins).

**Spec:** This plan implements the approved design from conversation (2026-09-06). Final user decisions are binding and already incorporated:
1. **C — import everything, keep the 119 base weapons** (they are in `items_index.json`; full re-import restores them; NO filter).
2. **Delete all stale tests** (17 test files referencing non-existent models) — delete outright, no failure-verify step.
3. **Keep `bsg_id` as a column but never use it for logic** → unlock-graph `item_id` columns are bigint FK to `items.id`, resolved at import via `Item.find_by(bsg_id: raw)&.id` (NULL when item absent); `item_name` kept for display; `Item` logic uses internal `id`.
4. **No descriptions/about data — names only** → no `description` column; no wiki Description section.

---

## Global Constraints

- Kill Rails server before schema work: `kill $(lsof -t -i:3000)`
- **100% TDD: every line of implementation code is written only after a failing test that exercises it.** No implementation code without a preceding failing test. Tests are written "like a person using the app" (integration tests hitting routes, not unit-only). Each task's test-first step is mandatory, not optional.
- Rails/rake via `bundle exec`; Python via `~/.pyvenv-tarkov/bin/python`
- AGENTS.md: wikitext parsing MUST use `mwparserfromhell` (Python) — regex only for tabber/table internals and 24-hex id extraction
- NO price/market/flea data anywhere (user pruned all of it)
- `bsg_id` is matching-only, never used for logic
- CI target: `bundle exec rake ci:all` — coverage ≥89%, rubycritic ≥75
- Run `bundle exec annotate` after migrations (annotaterb is in Gemfile)
- Commit after each task

---

## Task 0: Commit Working Tree

**Files:** (none new)

- [ ] **Step 1: Commit all uncommitted work**

The working tree has uncommitted admin CRUD work (admin controllers/views, AdminCrud concern, Tailwind build, task chain sync rake task, etc.) plus a seeds.rb RuboCop space change. Commit it all with a message matching repo style (e.g. `Add admin CRUD panel and task chain sync`). Do NOT clobber any of it.

- [ ] **Step 2: Verify clean tree**

Run: `git status --short` → expect clean.

---

## Task 1: Full Do-Over — Delete Everything, Recreate Schema + All Models

**Files:**
- Delete ALL migrations: `db/migrate/20260905000000_create_all_tables.rb`, `db/migrate/20260905000001_add_filters_to_slots.rb`, `db/migrate/20260905214724_add_leads_tos_count_to_tasks.rb`, `db/migrate/20260905214828_add_previous_tasks_count_to_requirements.rb`
- Delete ALL domain models (keep `app/models/application_record.rb`): `property.rb`, `slot.rb`, `item.rb`, `item_currency.rb`, `item_task_reward.rb`, `item_hideout.rb`, `item_barter.rb`, `task.rb`, `leads_to.rb`, `requirement.rb`, `previous_task.rb`, `reward.rb`, `loose_item.rb`, `offer_unlock.rb`, `barter_unlock.rb`, `barter_requirement.rb`, `barter_requirement_item.rb`, `barter_result.rb`, `barter_result_item.rb`, `craft_unlock.rb`, `craft_requirement.rb`, `craft_requirement_item.rb`, `craft_result.rb`, `craft_result_item.rb`
- Create: `db/migrate/20260906000000_create_items.rb`, `db/migrate/20260906000001_create_task_graph.rb`
- Create ALL models fresh (see Step 4)
- Modify: `config/routes.rb` (remove `:properties, :slots` from admin resources)
- Modify: `app/views/admin/layouts/application.html.erb` (remove Properties/Slots nav links)
- Delete stale tests + fixtures (see Step 6)

**Interfaces:**
- Produces: complete new schema (items + obtain tables + full task graph) and all models
- Consumes: nothing

- [ ] **Step 1: Kill server, delete all migrations and all models**

```bash
kill $(lsof -t -i:3000) 2>/dev/null; true
rm db/migrate/*.rb
rm app/models/property.rb app/models/slot.rb app/models/item.rb \
   app/models/item_currency.rb app/models/item_task_reward.rb \
   app/models/item_hideout.rb app/models/item_barter.rb \
   app/models/task.rb app/models/leads_to.rb app/models/requirement.rb \
   app/models/previous_task.rb app/models/reward.rb app/models/loose_item.rb \
   app/models/offer_unlock.rb app/models/barter_unlock.rb \
   app/models/barter_requirement.rb app/models/barter_requirement_item.rb \
   app/models/barter_result.rb app/models/barter_result_item.rb \
   app/models/craft_unlock.rb app/models/craft_requirement.rb \
   app/models/craft_requirement_item.rb app/models/craft_result.rb \
   app/models/craft_result_item.rb
```

- [ ] **Step 2: Create items migration**

```ruby
# db/migrate/20260906000000_create_items.rb
class CreateItems < ActiveRecord::Migration[8.1]
  def change
    create_table :items do |t|
      t.string :type, null: false, default: "Item::Generic"
      t.string :bsg_id
      t.string :slug
      t.string :full_name
      t.string :short_name
      t.string :wiki_title
      t.text :categories, array: true, default: []
      t.text :links, array: true, default: []
      t.text :images, array: true, default: []
      t.jsonb :data, null: false, default: {}
      t.timestamps
    end
    add_index :items, :bsg_id, unique: true
    add_index :items, :type
    add_index :items, :slug
  end
end
```

- [ ] **Step 3: Create full task graph migration**

All `item_id` columns are nullable bigint FK → `items.id` (decision 3: bsg_id resolved to internal id at import; NULL when item absent). All `task_id`/`follow_up_task_id` columns are nullable bigint FK → `tasks.id` (resolved at import; NULL when task absent). `leads_tos_count` on tasks and `previous_tasks_count` on requirements are included directly (they were separate migrations in the old schema).

```ruby
# db/migrate/20260906000001_create_task_graph.rb
class CreateTaskGraph < ActiveRecord::Migration[8.1]
  def change
    # --- obtain graph (item → how to get it) ---
    create_table :item_currencies do |t|
      t.references :item, null: false, foreign_key: true
      t.string :trader
      t.string :currency
      t.integer :min_trader_level
      t.boolean :task_unlock, null: false, default: false
      t.timestamps
    end

    create_table :item_task_rewards do |t|
      t.references :item, null: false, foreign_key: true
      t.references :task, foreign_key: true
      t.string :task_name
      t.timestamps
    end

    create_table :item_hideouts do |t|
      t.references :item, null: false, foreign_key: true
      t.string :station
      t.integer :level
      t.timestamps
    end

    create_table :item_barters do |t|
      t.references :item, null: false, foreign_key: true
      t.string :trader
      t.string :trader_level
      t.string :currency
      t.integer :cost
      t.string :item_name
      t.timestamps
    end

    # --- tasks ---
    create_table :tasks do |t|
      t.string :bsg_id
      t.string :full_name
      t.string :name
      t.string :wiki_link
      t.string :given_by
      t.boolean :kappa_required
      t.boolean :lightkeeper_required
      t.integer :leads_tos_count, null: false, default: 0
      t.timestamps
    end

    create_table :leads_tos do |t|
      t.references :task, null: false, foreign_key: true
      t.references :follow_up_task, foreign_key: { to_table: :tasks }
      t.string :follow_up_task_name
      t.timestamps
    end

    create_table :requirements do |t|
      t.references :task, null: false, foreign_key: true
      t.integer :player_level
      t.integer :previous_tasks_count, null: false, default: 0
      t.timestamps
    end

    create_table :previous_tasks do |t|
      t.references :requirement, null: false, foreign_key: true
      t.references :task, foreign_key: true
      t.string :task_name
      t.timestamps
    end

    create_table :rewards do |t|
      t.references :task, null: false, foreign_key: true
      t.string :reward_type
      t.timestamps
    end

    # --- unlock graph (item_id = FK to items.id, resolved at import) ---
    create_table :loose_items do |t|
      t.references :reward, null: false, foreign_key: true
      t.references :item, foreign_key: true
      t.string :item_name
      t.integer :count
      t.timestamps
    end

    create_table :offer_unlocks do |t|
      t.references :reward, null: false, foreign_key: true
      t.references :item, foreign_key: true
      t.string :item_name
      t.string :trader_name
      t.string :trader_level
      t.timestamps
    end

    create_table :barter_unlocks do |t|
      t.references :reward, null: false, foreign_key: true
      t.references :item, foreign_key: true
      t.string :item_name
      t.timestamps
    end

    create_table :barter_requirements do |t|
      t.references :barter_unlock, null: false, foreign_key: true
      t.string :trader_name
      t.string :trader_level
      t.timestamps
    end

    create_table :barter_requirement_items do |t|
      t.references :barter_requirement, null: false, foreign_key: true
      t.references :item, foreign_key: true
      t.string :item_name
      t.integer :count
      t.timestamps
    end

    create_table :barter_results do |t|
      t.references :barter_unlock, null: false, foreign_key: true
      t.timestamps
    end

    create_table :barter_result_items do |t|
      t.references :barter_result, null: false, foreign_key: true
      t.references :item, foreign_key: true
      t.string :item_name
      t.timestamps
    end

    create_table :craft_unlocks do |t|
      t.references :reward, null: false, foreign_key: true
      t.references :item, foreign_key: true
      t.string :item_name
      t.string :hideout_station
      t.integer :station_level
      t.timestamps
    end

    create_table :craft_requirements do |t|
      t.references :craft_unlock, null: false, foreign_key: true
      t.string :trader_name
      t.string :trader_level
      t.timestamps
    end

    create_table :craft_requirement_items do |t|
      t.references :craft_requirement, null: false, foreign_key: true
      t.references :item, foreign_key: true
      t.string :item_name
      t.integer :count
      t.timestamps
    end

    create_table :craft_results do |t|
      t.references :craft_unlock, null: false, foreign_key: true
      t.timestamps
    end

    create_table :craft_result_items do |t|
      t.references :craft_result, null: false, foreign_key: true
      t.references :item, foreign_key: true
      t.string :item_name
      t.timestamps
    end
  end
end
```

- [ ] **Step 4: Recreate all models**

Write failing model tests first (100% TDD), then create:

- `app/models/item.rb` — STI base (full code in Task 2)
- `app/models/item/weapon.rb` + 9 more type classes (Task 2)
- `app/models/item_currency.rb` — `belongs_to :item`
- `app/models/item_task_reward.rb` — `belongs_to :item`, `belongs_to :task, optional: true`
- `app/models/item_hideout.rb` — `belongs_to :item`
- `app/models/item_barter.rb` — `belongs_to :item`
- `app/models/task.rb` — `has_many :rewards`, `has_many :leads_tos`, `has_many :requirements`, `has_many :item_task_rewards`; counter cache `leads_tos_count`
- `app/models/leads_to.rb` — `belongs_to :task`, `belongs_to :follow_up_task, class_name: "Task", optional: true`
- `app/models/requirement.rb` — `belongs_to :task`, `has_many :previous_tasks`; counter cache `previous_tasks_count`
- `app/models/previous_task.rb` — `belongs_to :requirement`, `belongs_to :task, optional: true`
- `app/models/reward.rb` — `belongs_to :task`, `has_many :loose_items`, `has_many :offer_unlocks`, `has_many :barter_unlocks`, `has_many :craft_unlocks`
- `app/models/loose_item.rb` — `belongs_to :reward`, `belongs_to :item, optional: true`
- `app/models/offer_unlock.rb` — `belongs_to :reward`, `belongs_to :item, optional: true`
- `app/models/barter_unlock.rb` — `belongs_to :reward`, `belongs_to :item, optional: true`, `has_many :barter_requirements`, `has_many :barter_results`
- `app/models/barter_requirement.rb` — `belongs_to :barter_unlock`, `has_many :barter_requirement_items`
- `app/models/barter_requirement_item.rb` — `belongs_to :barter_requirement`, `belongs_to :item, optional: true`
- `app/models/barter_result.rb` — `belongs_to :barter_unlock`, `has_many :barter_result_items`
- `app/models/barter_result_item.rb` — `belongs_to :barter_result`, `belongs_to :item, optional: true`
- `app/models/craft_unlock.rb` — `belongs_to :reward`, `belongs_to :item, optional: true`, `has_many :craft_requirements`, `has_many :craft_results`
- `app/models/craft_requirement.rb` — `belongs_to :craft_unlock`, `has_many :craft_requirement_items`
- `app/models/craft_requirement_item.rb` — `belongs_to :craft_requirement`, `belongs_to :item, optional: true`
- `app/models/craft_result.rb` — `belongs_to :craft_unlock`, `has_many :craft_result_items`
- `app/models/craft_result_item.rb` — `belongs_to :craft_result`, `belongs_to :item, optional: true`

Preserve the existing behavior of `Task` (scopes, `chains`/`chain_for` methods used by `tasks_controller.rb` and `lib/tasks/sync_task_chains_from_wiki.rake`) — read the old model from git (`git show HEAD:app/models/task.rb`) and port it to the new schema.

- [ ] **Step 5: Reset database**

```bash
bundle exec rails db:drop db:create db:migrate
bundle exec annotate
```

- [ ] **Step 6: Delete stale tests and fixtures**

Delete these test files (they reference models that no longer exist — verified to exist ONLY in test files, no models):
`test/models/item_property_test.rb`, `item_slot_test.rb`, `item_slot_filter_test.rb`, `item_armor_slot_test.rb`, `item_armor_plate_test.rb`, `item_type_test.rb`, `buyable_test.rb`, `craft_test.rb`, `trader_test.rb`, `buyable_task_requirement_test.rb`, `craft_task_requirement_test.rb`, `barter_task_requirement_test.rb`, `task_gated_buyable_test.rb`, `task_gated_craft_test.rb`, `task_gated_barter_test.rb`, `task_gated_craft_unlock_test.rb`, `task_gated_barter_unlock_test.rb`.

Delete these fixtures: `item_properties.yml`, `item_slots.yml`, `item_slot_filters.yml`, `item_armor_slots.yml`, `item_armor_plates.yml`, `item_types.yml`, `buyables.yml`, `crafts.yml`, `traders.yml`, `task_gated_buyables.yml`, `task_gated_crafts.yml`, `task_gated_barters.yml`, `task_gated_craft_unlocks.yml`, `task_gated_barter_unlocks.yml`, `buyable_task_requirements.yml`, `craft_task_requirements.yml`, `barter_task_requirements.yml`.

- [ ] **Step 7: Update routes and admin layout**

`config/routes.rb` line 10: remove `:properties, :slots` from the admin resources list. `app/views/admin/layouts/application.html.erb`: remove the Properties/Slots nav links.

- [ ] **Step 8: Run tests**

Run: `bundle exec rails test`
Expected: remaining tests pass (task graph tests, admin tests, items tests — update any that reference `properties`/`slots` or old column names).

- [ ] **Step 9: Commit**

---

## Task 2: Item Model + Type Classes

**Files:**
- Rewrite: `app/models/item.rb`
- Create: `app/models/item/weapon.rb`, `ammo.rb`, `armor.rb`, `key.rb`, `magazine.rb`, `container.rb`, `medical.rb`, `provision.rb`, `throwable.rb`, `generic.rb`
- Modify: `test/models/item_test.rb`, `test/fixtures/items.yml`

**Interfaces:**
- Produces: `Item` STI base with `type_for`, obtain associations, `requires_task?`/`task_gated`/`how_to_unlock`/`unlock_details_for` using internal `id`
- Consumes: `Item::*` type classes

- [ ] **Step 1: Write failing tests first**

Tests (integration-style, "like a person using the app"):
- `Item.type_for("ItemPropertiesWeapon", nil)` → `Item::Weapon`; `Item.type_for("ItemPropertiesAmmo", nil)` → `Item::Ammo`; `Item.type_for("ItemPropertiesArmor", nil)` → `Item::Armor`; `Item.type_for("ItemPropertiesKey", nil)` → `Item::Key`; `Item.type_for("ItemPropertiesMagazine", nil)` → `Item::Magazine`; `Item.type_for("ItemPropertiesContainer", nil)` → `Item::Container`; `Item.type_for("ItemPropertiesMedKit", nil)` → `Item::Medical`; `Item.type_for("ItemPropertiesFoodDrink", nil)` → `Item::Provision`; `Item.type_for("ItemPropertiesGrenade", nil)` → `Item::Throwable`; `Item.type_for("ItemPropertiesUnknown", nil)` → `Item::Generic`; `Item.type_for("ItemPropertiesWeapon", "weapon")` → `Item::Weapon` (wiki infobox overrides); `Item.type_for(nil, nil)` → `Item::Generic`
- `Item::Weapon.new` is an `Item`; `Item::Weapon.sti_name` == "Item::Weapon"
- `requires_task?`/`task_gated`/`how_to_unlock`/`unlock_details_for` work with internal `id` (fixture item with `item_currencies`/`item_task_rewards` rows referencing `items.id`)
- `data` is JSONB: `item.data = '{"caliber": "5.45x39mm"}'` stores hash; `item.data = { "caliber" => "5.45x39mm" }` stores hash

- [ ] **Step 2: Rewrite Item model**

```ruby
# app/models/item.rb
class Item < ApplicationRecord
  has_many :item_task_rewards, dependent: :destroy
  has_many :item_hideouts, dependent: :destroy
  has_many :item_barters, dependent: :destroy
  has_many :item_currencies, dependent: :destroy

  TYPE_MAP = {
    "Weapon" => "Item::Weapon",
    "Ammo" => "Item::Ammo",
    "Armor" => "Item::Armor",
    "Key" => "Item::Key",
    "Magazine" => "Item::Magazine",
    "Container" => "Item::Container",
    "Medical" => "Item::Medical",
    "Provision" => "Item::Provision",
    "Throwable" => "Item::Throwable"
  }.freeze

  def self.type_for(properties_type, wiki_infobox = nil)
    # source uses "ItemPropertiesWeapon" — strip the prefix; wiki infobox wins
    base = wiki_infobox.to_s.camelize
    base = properties_type.to_s.sub(/\AItemProperties/, "") if base.blank?
    (TYPE_MAP[base] || "Item::Generic").constantize
  end

  def data=(value)
    super(value.is_a?(String) ? JSON.parse(value) : value)
  rescue JSON::ParserError
    errors.add(:data, "must be valid JSON")
    super({})
  end

  # --- obtain graph (uses internal id) ---

  ObtainEntry = Struct.new(:type, :source, keyword_init: true)
  UnlockPath = Struct.new(:task, :reward_type, :unlock_method, keyword_init: true)

  def obtain_from
    entries = []
    item_task_rewards.find_each { |r| entries << ObtainEntry.new(type: :task_reward, source: r) }
    item_hideouts.find_each { |r| entries << ObtainEntry.new(type: :hideout, source: r) }
    item_barters.find_each { |r| entries << ObtainEntry.new(type: :barter, source: r) }
    item_currencies.find_each { |r| entries << ObtainEntry.new(type: :currency, source: r) }
    entries
  end

  def obtain_types
    obtain_from.map(&:type).uniq
  end

  def obtain_from_tasks
    obtain_from.select { |e| e.type == :task_reward }
  end

  def obtain_from_hideouts
    obtain_from.select { |e| e.type == :hideout }
  end

  def obtain_from_barters
    obtain_from.select { |e| e.type == :barter }
  end

  def obtain_from_currencies
    obtain_from.select { |e| e.type == :currency }
  end

  def requires_task?
    %w[OfferUnlock BarterUnlock CraftUnlock].any? do |model_name|
      model_name.constantize.exists?(item_id: id)
    end
  end

  scope :task_gated, -> {
    where(id: [ OfferUnlock.pluck(:item_id), BarterUnlock.pluck(:item_id), CraftUnlock.pluck(:item_id) ].flatten.uniq)
  }

  def self.search(query)
    return all if query.blank?
    q = "%#{query}%"
    where("slug ILIKE ? OR full_name ILIKE ? OR short_name ILIKE ?", q, q, q)
  end

  def how_to_unlock
    paths = []
    Reward.joins(:offer_unlocks).where(offer_unlocks: { item_id: id }).find_each do |reward|
      paths << UnlockPath.new(task: reward.task, reward_type: reward.reward_type, unlock_method: :offer_unlock)
    end
    Reward.joins(:barter_unlocks).where(barter_unlocks: { item_id: id }).find_each do |reward|
      paths << UnlockPath.new(task: reward.task, reward_type: reward.reward_type, unlock_method: :barter_unlock)
    end
    Reward.joins(:craft_unlocks).where(craft_unlocks: { item_id: id }).find_each do |reward|
      paths << UnlockPath.new(task: reward.task, reward_type: reward.reward_type, unlock_method: :craft_unlock)
    end
    paths.uniq
  end

  def unlock_details_for(path)
    reward = path.task.rewards.where(reward_type: path.reward_type).first
    return nil unless reward

    case path.unlock_method
    when :craft_unlock
      craft_unlock = reward.craft_unlocks.where(item_id: id).first
      return nil unless craft_unlock
      details = []
      details << "Craft at #{craft_unlock.hideout_station} Level #{craft_unlock.station_level}"
      craft_unlock.craft_requirements.each do |req|
        next if req.trader_level.blank?
        details << "Requires #{req.trader_name.titleize} LL#{req.trader_level}"
      end
      craft_unlock.craft_requirements.flat_map(&:craft_requirement_items).each do |item|
        details << "#{item.item_name} x#{item.count}"
      end
      details.join(" · ")
    when :barter_unlock
      barter_unlock = reward.barter_unlocks.where(item_id: id).first
      return nil unless barter_unlock
      details = []
      barter_unlock.barter_requirements.each do |req|
        details << "#{req.trader_name.titleize} LL#{req.trader_level}"
      end
      items = barter_unlock.barter_results.flat_map(&:barter_result_items).map(&:item_name)
      details << "Gives: #{items.join(", ")}" if items.any?
      barter_unlock.barter_requirements.flat_map(&:barter_requirement_items).each do |item|
        details << "#{item.item_name} x#{item.count}"
      end
      details.join(" · ")
    when :offer_unlock
      offer_unlock = reward.offer_unlocks.where(item_id: id).first
      return nil unless offer_unlock
      "#{offer_unlock.trader_name.titleize} LL#{offer_unlock.trader_level}"
    else
      nil
    end
  end
end
```

- [ ] **Step 3: Create type classes**

```ruby
# app/models/item/weapon.rb
class Item::Weapon < Item
end
```

Same one-liner for `ammo.rb`, `armor.rb`, `key.rb`, `magazine.rb`, `container.rb`, `medical.rb`, `provision.rb`, `throwable.rb`, `generic.rb`.

- [ ] **Step 4: Update fixtures**

`test/fixtures/items.yml` — new schema fields: `type`, `bsg_id`, `slug`, `full_name`, `short_name`, `wiki_title`, `categories`, `links`, `images`, `data`. Keep `one`/`two` names used by other fixtures/tests.

- [ ] **Step 5: Run tests**

Run: `bundle exec rails test`
Expected: all pass.

- [ ] **Step 6: Commit**

---

## Task 3: Importers::Index

**Files:**
- Create: `app/services/importers/index.rb`
- Create: `test/services/importers/index_test.rb`

**Interfaces:**
- Produces: `Importers::Index.import!` — upserts items from `offlinedata/tarkovunlockables/items_index.json`
- Consumes: `Item`, `Item.type_for`

- [ ] **Step 1: Write failing test first**

Test with a small fixture JSON (temp file) matching the VERIFIED source shape (snake_case keys — see pre-flight scan): creates items with `bsg_id`, `slug`, `full_name`, `short_name`, `categories`, `properties` → `data`, `obtain_from` → obtain rows. Verifies:
- item created with correct type via `Item.type_for(properties_type)` — source uses `ItemPropertiesWeapon` prefix
- `data` contains kept properties (e.g. weapon `caliber`, `allowed_ammo`, `default_ammo`, `presets`, `slots`; ammo `caliber`, `ammo_type`, `damage`, `penetration_power`; armor `class`, `armor_type`, `armor_slots`, `zones`)
- `links`/`images` NOT imported (skipped per prune)
- `obtain_from` (shape `[{ "task_rewards": [...], "hideout": [...], "barter": [...], "currency": [...] }]`) → `item_task_rewards` (task_name), `item_hideouts` (station/level), `item_barters` (trader/trader_level), `item_currencies` (trader/currency/min_trader_level)
- idempotent: running twice doesn't duplicate
- base weapons (gun category + empty short_name) ARE imported (decision 1C — no filter)

- [ ] **Step 2: Implement**

```ruby
# app/services/importers/index.rb
module Importers
  class Index
    SOURCE = Rails.root.join("offlinedata/tarkovunlockables/items_index.json")

    # snake_case keys actually present in items_index.json properties
    KEPT_PROPERTIES = %w[
      caliber allowed_ammo default_ammo default_preset presets slots
      ammo_type damage penetration_power class armor_type armor_slots zones
      slash_damage stab_damage base_item default type
    ].freeze

    def self.import!
      new.import!
    end

    def import!
      data = JSON.parse(File.read(SOURCE))
      data.each { |raw| import_item(raw) }
    end

    private

    def import_item(raw)
      item = Item.find_or_initialize_by(bsg_id: raw["bsg_id"])
      item.type = Item.type_for(raw.dig("properties", "properties_type")).name
      item.slug = raw["slug"]
      item.full_name = raw["full_name"]
      item.short_name = raw["short_name"]
      item.categories = raw["categories"] || []
      item.data = kept_properties(raw["properties"] || {})
      item.save!
      import_obtain_from(item, raw["obtain_from"] || [])
    end

    def kept_properties(props)
      props.slice(*KEPT_PROPERTIES)
    end

    def import_obtain_from(item, entries)
      item.item_currencies.destroy_all
      item.item_task_rewards.destroy_all
      item.item_hideouts.destroy_all
      item.item_barters.destroy_all

      entries.each do |entry|
        (entry["task_rewards"] || []).each do |tr|
          item.item_task_rewards.create!(task_name: tr["task_name"])
        end
        (entry["hideout"] || []).each do |h|
          item.item_hideouts.create!(station: h["station_name"], level: h["station_level"])
        end
        (entry["barter"] || []).each do |b|
          item.item_barters.create!(trader: b["trader_name"], trader_level: b["trader_level"])
        end
        (entry["currency"] || []).each do |c|
          item.item_currencies.create!(
            trader: c["trader_name"],
            currency: c["currency"],
            min_trader_level: c["trader_level"].to_s.gsub(/LL/i, "").to_i
          )
        end
      end
    end
  end
end
```

Note: `item_task_rewards.task_id` is nullable FK — resolved in Task 7 (seeds) when tasks exist; here only `task_name` is set. `item_barters` needs a `trader_level` column (source has `trader_level` like "LL2") — Task 1's migration must include it.

- [ ] **Step 3: Run tests**

Run: `bundle exec rails test test/services/importers/index_test.rb`
Expected: pass.

- [ ] **Step 4: Commit**

---

## Task 4: Importers::TarkovDev

**Files:**
- Create: `app/services/importers/tarkov_dev.rb`
- Create: `test/services/importers/tarkov_dev_test.rb`

**Interfaces:**
- Produces: `Importers::TarkovDev.import!` — enriches items from `offlinedata/tarkovdev/items.json` (keyed by bsg_id)
- Consumes: `Item`

- [ ] **Step 1: Write failing test first**

Test with small fixture: item already exists (from Index import); TarkovDev import enriches `data` with kept properties, `containsItems`, `types`, `categories`, `wikiLink`/`link` → `links`, images → `images`, `buyFromTrader` → `item_currencies` (trader/currency/minTraderLevel/taskUnlock). Verifies:
- `data` gets weapon `caliber`, `allowedAmmo`, `slots`, `presets`, `defaultPreset`; ammo `caliber`, `stackMaxSize`, `tracer`, `tracerColor`, `ammoType`, `damage`, `penetrationPower`; armor `class`
- pruned props NOT stored (ergonomics, recoilVertical, fireRate, ballisticCoeficient, armorDamage, etc.)
- `containsItems` stored
- `buyFromTrader` → `item_currencies` rows
- idempotent

- [ ] **Step 2: Implement**

```ruby
# app/services/importers/tarkov_dev.rb
module Importers
  class TarkovDev
    SOURCE = Rails.root.join("offlinedata/tarkovdev/items.json")

    WEAPON_PROPS = %w[caliber allowedAmmo slots presets defaultPreset].freeze
    AMMO_PROPS = %w[caliber stackMaxSize tracer tracerColor ammoType damage penetrationPower].freeze
    ARMOR_PROPS = %w[class].freeze
    COMMON_PROPS = %w[types categories containsItems].freeze

    def self.import!
      new.import!
    end

    def import!
      data = JSON.parse(File.read(SOURCE))
      data.fetch("data", data).each do |bsg_id, raw|
        item = Item.find_by(bsg_id: bsg_id)
        next unless item
        import_item(item, raw)
      end
    end

    private

    def import_item(item, raw)
      item.links = [raw["wikiLink"], raw["link"]].compact if raw["wikiLink"] || raw["link"]
      item.images = [raw["iconLink"], raw["gridImageLink"], raw["baseImageLink"],
                     raw["inspectImageLink"], raw["image512pxLink"], raw["image8xLink"]].compact
      item.data = item.data.merge(kept_properties(raw))
      item.save!
      import_buy_from_trader(item, raw["buyFromTrader"] || [])
    end

    def kept_properties(raw)
      props = {}
      props["types"] = raw["types"] if raw["types"]
      props["categories"] = raw["categories"] if raw["categories"]
      props["containsItems"] = raw["containsItems"] if raw["containsItems"]

      case raw["propertiesType"]
      when "Weapon"
        WEAPON_PROPS.each { |k| props[k] = raw[k] if raw.key?(k) }
      when "Ammo"
        AMMO_PROPS.each { |k| props[k] = raw[k] if raw.key?(k) }
      when "Armor"
        ARMOR_PROPS.each { |k| props[k] = raw[k] if raw.key?(k) }
      end
      props
    end

    def import_buy_from_trader(item, entries)
      entries.each do |entry|
        item.item_currencies.find_or_create_by!(
          trader: entry.dig("trader", "name"),
          currency: entry["currency"],
          min_trader_level: entry["minTraderLevel"],
          task_unlock: entry["taskUnlock"] || false
        )
      end
    end
  end
end
```

- [ ] **Step 3: Run tests**

Run: `bundle exec rails test test/services/importers/tarkov_dev_test.rb`
Expected: pass.

- [ ] **Step 4: Commit**

---

## Task 5: Importers::Market

**Files:**
- Create: `app/services/importers/market.rb`
- Create: `test/services/importers/market_test.rb`

**Interfaces:**
- Produces: `Importers::Market.import!` — fixes names from `offlinedata/tarkovmarket/items_all.json` (flat array with `bsgId`)
- Consumes: `Item`

- [ ] **Step 1: Write failing test first**

Test: item exists with wrong/blank name; Market import sets `full_name`/`short_name` from `name`/`shortName`. Verifies NO price fields stored (basePrice, avg24hPrice, etc. all skipped). Idempotent.

- [ ] **Step 2: Implement**

```ruby
# app/services/importers/market.rb
module Importers
  class Market
    SOURCE = Rails.root.join("offlinedata/tarkovmarket/items_all.json")

    def self.import!
      new.import!
    end

    def import!
      data = JSON.parse(File.read(SOURCE))
      data.each do |raw|
        item = Item.find_by(bsg_id: raw["bsgId"])
        next unless item
        item.full_name = raw["name"] if raw["name"].present?
        item.short_name = raw["shortName"] if raw["shortName"].present?
        item.save!
      end
    end
  end
end
```

- [ ] **Step 3: Run tests**

Run: `bundle exec rails test test/services/importers/market_test.rb`
Expected: pass.

- [ ] **Step 4: Commit**

---

## Task 6: Wiki Parser + Importers::Wiki

**Files:**
- Create: `lib/wiki_parser/parse_itembatches.py`
- Create: `lib/wiki_parser/test_parse_itembatches.py`
- Create: `lib/tasks/parse_wiki.rake`
- Create: `app/services/importers/wiki.rb`
- Create: `test/services/importers/wiki_test.rb`
- Modify: `.gitignore` (add `offlinedata/officialwiki/parsed_items.json`)

**Interfaces:**
- Produces: `parsed_items.json` (bsg_id → { full_name, infobox, sections }); `Importers::Wiki.import!` (wiki wins)
- Consumes: `mwparserfromhell` (0.7.2, venv `~/.pyvenv-tarkov/bin/python`), `offlinedata/officialwiki/itembatches/wiki_batch_*.json`

- [ ] **Step 1: Write Python parser tests first**

`test_parse_itembatches.py` (unittest, run with `~/.pyvenv-tarkov/bin/python -m unittest`):
- parses a sample batch file → dict keyed by 24-hex node id
- infobox params extracted with exact wiki spelling: `Weaprecoil`, `fire modes`, `def ammo`, `def mag`, `sightrange`, `MOA`, `rof`, `ID`, `node`, `caliber`, `penetration`, `armor`, `default plates`, `default plates armor class`, `max uses`, `ergonomics`, `recoil`, `range`, `velocity`, `effect`, `type`, `slot`, `trader`
- values cleaned: units stripped ("0.01 kg" → "0.01", "838 m/s" → "838"), HTML font tags removed
- `==Mods==` section parsed from `<tabber>`: each `Slot=\n<div class="mobileonly">'''Slot'''</div>\n{{24-hex-id}}<br/>…` → slot name + list of hex ids (last entry may lack trailing `<br/>`)
- `==Weapon variants==` section parsed from wikitable: rows → variant name + attachment hex ids (`{{24-hex-id}}<br/>` sequences; `![[File:…]]` header cells skipped)
- `node` multi-line list with `(Color)` annotations → first hex id only
- interwiki `[[fr:…]]`, `[[ru:…]]`, `[[Category:…]]`, `{{Navbox…}}` filtered out
- pages without infobox (stubs) skipped

- [ ] **Step 2: Implement parser**

`lib/wiki_parser/parse_itembatches.py`:
- Input: `offlinedata/officialwiki/itembatches/wiki_batch_*.json` (format: `query.pages[].revisions[0].slots.main.content` wikitext)
- Output: `offlinedata/officialwiki/parsed_items.json` — `{ bsg_id: { "full_name": ..., "infobox": {...}, "sections": { "mods": [...], "weapon_variants": [...] } } }`
- Use `mwparserfromhell` for template/wikilink extraction; regex ONLY for tabber/table internals and 24-hex ids (`[0-9a-f]{24}`)
- `node` param → bsg_id key; skip pages without node or without infobox
- Strip units/HTML from values; keep raw strings otherwise

- [ ] **Step 3: Create rake task**

```ruby
# lib/tasks/parse_wiki.rake
namespace :wiki do
  desc "Parse officialwiki itembatches into parsed_items.json"
  task parse: :environment do
    py = File.expand_path("~/.pyvenv-tarkov/bin/python")
    script = Rails.root.join("lib/wiki_parser/parse_itembatches.py")
    system(py, script.to_s) or abort "wiki parse failed"
  end
end
```

- [ ] **Step 4: Write Importers::Wiki test first**

Test: item exists (from earlier importers); wiki import overwrites `full_name` (wiki wins), sets `wiki_title`, merges `data` with infobox params (kept set), stores `mods`/`weapon_variants` sections. Verifies:
- wiki `full_name` beats market name
- `data["caliber"]`, `data["penetration"]`, `data["armor"]`, `data["maxUses"]`, `data["ergonomics"]`, `data["effect"]` etc. set from infobox
- `data["mods"]` = [{slot, items: [hex ids]}], `data["weapon_variants"]` = [{name, attachments: [hex ids]}]
- pruned infobox params NOT stored (image, icon, weight, grid, price, fire modes, sightrange, MOA, rof, etc.)
- idempotent

- [ ] **Step 5: Implement Importers::Wiki**

```ruby
# app/services/importers/wiki.rb
module Importers
  class Wiki
    SOURCE = Rails.root.join("offlinedata/officialwiki/parsed_items.json")

    KEPT_INFOBOX = %w[type slot trader node ID caliber def_ammo ammo penetration armor
                      default_plates default_plates_armor_class max_uses ergonomics recoil
                      range velocity effect].freeze

    def self.import!
      new.import!
    end

    def import!
      data = JSON.parse(File.read(SOURCE))
      data.each do |bsg_id, parsed|
        item = Item.find_by(bsg_id: bsg_id)
        next unless item
        item.wiki_title = parsed["full_name"]
        item.full_name = parsed["full_name"] if parsed["full_name"].present?
        item.data = item.data.merge(kept_infobox(parsed["infobox"] || {}))
        item.data["mods"] = parsed.dig("sections", "mods") if parsed.dig("sections", "mods").present?
        item.data["weapon_variants"] = parsed.dig("sections", "weapon_variants") if parsed.dig("sections", "weapon_variants").present?
        item.save!
      end
    end

    private

    def kept_infobox(infobox)
      infobox.slice(*KEPT_INFOBOX)
    end
  end
end
```

- [ ] **Step 6: Run all wiki tests**

Run: `~/.pyvenv-tarkov/bin/python -m unittest lib/wiki_parser/test_parse_itembatches.py` then `bundle exec rails test test/services/importers/wiki_test.rb`
Expected: pass.

- [ ] **Step 7: Commit**

---

## Task 7: Seeds Orchestration + Full Task Graph Import

**Files:**
- Rewrite: `db/seeds.rb`
- Create: `test/services/seeds_test.rb` (or extend an existing seed test)

**Interfaces:**
- Produces: idempotent full import: Index → TarkovDev → Market → Wiki, then the FULL task graph import from `offlinedata/tarkovunlockables/tasks_index.json` (tasks, rewards, requirements, leads_tos, previous_tasks, loose_items, offer_unlocks, barter_unlocks, craft_unlocks + nested requirement/result items) with `item_id`/`task_id` bsg_id → internal id resolved at insert time
- Consumes: all 4 importers, `Task`, `Reward`, unlock models, `tasks_index.json`

- [ ] **Step 1: Write failing test first**

Test: run seeds twice → item count unchanged second run; task graph rows not duplicated; `item_task_rewards.task_id` resolved to real task id when task exists; `item_id` on unlock tables (offer_unlocks/barter_unlocks/craft_unlocks/loose_items/barter_requirement_items/barter_result_items/craft_requirement_items/craft_result_items) resolved to `items.id` via bsg_id; NULL when item absent; `leads_tos.follow_up_task_id` and `previous_tasks.task_id` resolved to `tasks.id` via bsg_id; NULL when task absent.

- [ ] **Step 2: Rewrite seeds.rb**

```ruby
# db/seeds.rb
puts "Importing items (index → tarkovdev → market → wiki)..."
Importers::Index.import!
Importers::TarkovDev.import!
Importers::Market.import!
Importers::Wiki.import!

puts "Importing task graph..."
import_task_graph!

puts "Resolving item_task_rewards.task_id..."
ItemTaskReward.where(task_id: nil).find_each do |itr|
  task = Task.find_by(full_name: itr.task_name) || Task.find_by(name: itr.task_name)
  itr.update!(task_id: task.id) if task
end

puts "Done. Items: #{Item.count}, Tasks: #{Task.count}"

# --- task graph import (idempotent: per-task destroy + recreate) ---

def import_task_graph!
  json_dir = Rails.root.join("offlinedata/tarkovunlockables")
  tasks_data = JSON.parse(File.read(json_dir.join("tasks_index.json")))

  tasks_data.each do |task_data|
    task = Task.find_or_initialize_by(bsg_id: task_data["bsg_id"])
    task.assign_attributes(
      full_name: task_data["full_name"],
      name: task_data["name"],
      wiki_link: task_data["wiki_link"],
      given_by: task_data["given_by"],
      kappa_required: task_data["kappa_required"],
      lightkeeper_required: task_data["lightkeeper_required"]
    )
    task.save!

    task.leads_tos.destroy_all
    task.requirements.destroy_all
    task.rewards.destroy_all

    (task_data["leads_to"] || []).each do |lt|
      task.leads_tos.create!(
        follow_up_task_id: Task.find_by(bsg_id: lt["task_id"])&.id,
        follow_up_task_name: lt["task_name"]
      )
    end

    (task_data["requirements"] || []).each do |req|
      requirement = task.requirements.create!(player_level: req["player_level"].to_i)
      (req["previous_tasks"] || []).each do |pt|
        requirement.previous_tasks.create!(
          task_id: Task.find_by(bsg_id: pt["task_id"])&.id,
          task_name: pt["task_name"]
        )
      end
    end

    [ "start_rewards", "finish_rewards" ].each do |reward_type|
      (task_data[reward_type] || []).each do |reward_data|
        next if reward_data.nil?
        reward = task.rewards.create!(reward_type: reward_type)

        (reward_data["loose_items"] || []).each do |li|
          reward.loose_items.create!(
            item_id: Item.find_by(bsg_id: li["item_id"])&.id,
            item_name: li["item_name"],
            count: li["count"].to_i
          )
        end

        (reward_data["offer_unlocks"] || []).each do |ou|
          reward.offer_unlocks.create!(
            item_id: Item.find_by(bsg_id: ou["item_id"])&.id,
            item_name: ou["item_name"],
            trader_name: ou["trader_name"],
            trader_level: ou["trader_level"]
          )
        end

        (reward_data["barter_unlocks"] || []).each do |bu|
          result_items = bu.dig("result", 0, "items") || []
          first_item = result_items.first || {}
          barter_unlock = reward.barter_unlocks.create!(
            item_id: Item.find_by(bsg_id: first_item["item_id"])&.id,
            item_name: first_item["item_name"]
          )

          (bu["requirements"] || []).each do |req|
            barter_req = barter_unlock.barter_requirements.create!(
              trader_name: req["trader_name"],
              trader_level: req["trader_level"]
            )
            (req["items"] || []).each do |ri|
              barter_req.barter_requirement_items.create!(
                item_id: Item.find_by(bsg_id: ri["item_id"])&.id,
                item_name: ri["item_name"],
                count: ri["count"].to_i
              )
            end
          end

          (bu["result"] || []).each do |res|
            barter_result = barter_unlock.barter_results.create!
            (res["items"] || []).each do |ri|
              barter_result.barter_result_items.create!(
                item_id: Item.find_by(bsg_id: ri["item_id"])&.id,
                item_name: ri["item_name"]
              )
            end
          end
        end

        (reward_data["craft_unlocks"] || []).each do |cu|
          result_items = cu.dig("result", 0, "items") || []
          first_result_item = result_items.first || {}
          item_id = cu["item_id"].presence || first_result_item["id"]
          item_name = cu["item_name"].presence || first_result_item["name"]

          craft_unlock = reward.craft_unlocks.create!(
            item_id: Item.find_by(bsg_id: item_id)&.id,
            item_name: item_name,
            hideout_station: cu["hideout_station"],
            station_level: cu["station_level"].to_i
          )

          (cu["requirements"] || []).each do |req|
            craft_req = craft_unlock.craft_requirements.create!(
              trader_name: req["trader_name"],
              trader_level: req["trader_level"]
            )
            (req["items"] || []).each do |ri|
              craft_req.craft_requirement_items.create!(
                item_id: Item.find_by(bsg_id: ri["id"])&.id,
                item_name: ri["name"],
                count: ri["quantity"].to_i
              )
            end
          end

          (cu["result"] || []).each do |res|
            craft_result = craft_unlock.craft_results.create!
            (res["items"] || []).each do |ri|
              craft_result.craft_result_items.create!(
                item_id: Item.find_by(bsg_id: ri["id"])&.id,
                item_name: ri["name"]
              )
            end
          end
        end
      end
    end
  end
end
```

Note: `item_id` on all unlock tables is a nullable bigint FK to `items.id` (Task 1 migration). The import resolves bsg_id → `items.id` at insert time via `Item.find_by(bsg_id: ...)&.id`; NULL when the item is not in the DB. `item_name` is kept for display. `trader_level` stays a string ("LL2") — display code titleizes it.

- [ ] **Step 3: Run seeds**

Run: `bundle exec rails db:seed`
Expected: completes without error; item count > 3000; task count > 200.

- [ ] **Step 4: Run seeds again (idempotency)**

Run: `bundle exec rails db:seed`
Expected: no duplicates; counts stable.

- [ ] **Step 5: Run tests**

Run: `bundle exec rails test`
Expected: pass.

- [ ] **Step 6: Commit**

---

## Task 8: Public UI — JSONB Filters + Type Partials

**Files:**
- Modify: `app/controllers/items_controller.rb` (filters join `data` JSONB instead of `properties`)
- Modify: `app/views/items/show.html.erb` (render type partial)
- Create: `app/views/items/_weapon_stats.html.erb`, `_ammo_stats.html.erb`, `_armor_stats.html.erb`, `_key_stats.html.erb`, `_magazine_stats.html.erb`, `_container_stats.html.erb`, `_medical_stats.html.erb`, `_provision_stats.html.erb`, `_throwable_stats.html.erb`, `_generic_stats.html.erb`
- Modify: `app/models/item.rb` (add `stats_partial` method)
- Modify: `test/controllers/items_controller_test.rb`

**Interfaces:**
- Produces: type-specific stat display from `data` JSONB; filters on `data->>'class'`, `data->>'caliber'`
- Consumes: `Item` STI

- [ ] **Step 1: Write failing tests first**

- GET `/items?filter=class:6` returns only items with `data->>'class' == "6"` (armor class is stored under the `class` key — verified source key)
- GET `/items?filter=caliber:5.45x39mm` returns only matching
- GET `/items/:id` for a weapon renders weapon stats (caliber, def ammo, mods); for ammo renders penetration; for armor renders armor class; for key renders max uses; etc.
- unknown type renders generic partial without error

- [ ] **Step 2: Implement**

`Item#stats_partial`:
```ruby
def stats_partial
  "items/#{self.class.name.demodulize.underscore}_stats"
end
```

Controller filter:
```ruby
def filtered_items
  items = Item.all
  if params[:filter].present?
    key, value = params[:filter].split(":", 2)
    items = items.where("data->>? = ?", key, value)
  end
  items
end
```

Partials render from `item.data` with nil-safe access (e.g. `item.data["caliber"]`).

- [ ] **Step 3: Update obtain-from display in show.html.erb**

`app/views/items/show.html.erb` references old column names — update to the new schema:
- `entry.source.station_name` → `entry.source.station`; `entry.source.station_level` → `entry.source.level`
- `entry.source.trader_name` → `entry.source.trader` (item_barters and item_currencies)
- item_barters: `entry.source.trader_level` stays (string "LL2")
- item_currencies: `entry.source.trader_level` → `entry.source.min_trader_level` (integer)
- `path.reward_type` stays (Reward column unchanged)

- [ ] **Step 4: Run tests**

Run: `bundle exec rails test test/controllers/items_controller_test.rb`
Expected: pass.

- [ ] **Step 5: Commit**

---

## Task 9: Admin — Full Edit of Any DB Info

**Files:**
- Modify: `app/controllers/admin/items_controller.rb` (permit `data` as JSON string, nested obtain attributes)
- Modify: `app/views/admin/items/_form.html.erb` (JSON textarea for `data`, nested fields for item_currencies/item_task_rewards/item_hideouts/item_barters)
- Modify: `app/views/admin/items/show.html.erb` (render `data` pretty-printed)
- Modify: `app/models/item.rb` (accepts_nested_attributes_for obtain tables)
- Delete: `app/controllers/admin/properties_controller.rb`, `app/controllers/admin/slots_controller.rb` + their views/tests
- Modify: admin unlock controllers/forms/tests (offer_unlocks, barter_unlocks, craft_unlocks) — `item_id` now FK select of items
- Modify: `test/controllers/admin/items_controller_test.rb`

**Interfaces:**
- Produces: admin can edit ANY info in DB (names, categories, links, images, data JSON, obtain rows)
- Consumes: `Item#data=` (JSON string setter from Task 2)

- [ ] **Step 1: Write failing tests first**

- admin can update item with `data` JSON string param → stored as hash
- invalid JSON in `data` → validation error, not saved
- admin can add/remove `item_currencies` rows via nested params
- admin properties/slots routes gone (404)
- admin unlock forms submit `item_id` as internal id

- [ ] **Step 2: Implement**

`Item`:
```ruby
accepts_nested_attributes_for :item_currencies, :item_task_rewards, :item_hideouts, :item_barters,
                              allow_destroy: true
```

Controller `resource_params`:
```ruby
def resource_params
  params.require(:item).permit(
    :type, :bsg_id, :slug, :full_name, :short_name, :wiki_title, :data,
    categories: [], links: [], images: [],
    item_currencies_attributes: [:id, :trader, :currency, :min_trader_level, :task_unlock, :_destroy],
    item_task_rewards_attributes: [:id, :task_id, :task_name, :_destroy],
    item_hideouts_attributes: [:id, :station, :level, :_destroy],
    item_barters_attributes: [:id, :trader, :trader_level, :currency, :cost, :item_name, :_destroy]
  )
end
```

Form: textarea `form.text_area :data, value: item.data.to_json` + nested fields.

- [ ] **Step 3: Run tests**

Run: `bundle exec rails test test/controllers/admin/`
Expected: pass.

- [ ] **Step 4: Commit**

---

## Task 10: Full Re-import + Verification + CI

**Files:** (none new)

- [ ] **Step 1: Full re-import**

```bash
kill $(lsof -t -i:3000) 2>/dev/null; true
bundle exec rails db:drop db:create db:migrate
bundle exec rails db:seed
```

- [ ] **Step 2: Run seeds again (idempotency)**

Run: `bundle exec rails db:seed`
Expected: no duplicates, no errors.

- [ ] **Step 3: Verify restoration + integrity**

```bash
bundle exec rails runner '
  puts "items: #{Item.count}"
  puts "base weapons (gun category, empty short_name): #{Item.where("? = ANY (categories)", "gun").where(short_name: [nil, ""]).count}"
  puts "SVDS: #{Item.find_by(bsg_id: "5c46fbd72e2216398b5a8c9c")&.full_name}"
  puts "orphan item_currencies: #{ItemCurrency.where.not(item_id: Item.select(:id)).count}"
  puts "price data present: #{Item.where("data ? :k", k: "basePrice").count}"
'
```

Expected: items > 3000; base weapons restored (119 back); SVDS present; 0 orphans; 0 price data.

- [ ] **Step 4: Verify wiki data landed**

Check a known weapon (e.g. SVDS or AK-74M): `data` has `caliber`, `mods` array with slots, `weapon_variants` where applicable; `wiki_title` set.

- [ ] **Step 5: Full CI**

Run: `bundle exec rake ci:all`
Expected: security, lint, fasterer, boot, tests (≥89% coverage), rubycritic (≥75) all pass. Fix any failures.

- [ ] **Step 6: Commit**

---

## Task Order Summary

| # | Task | Hours |
|---|------|-------|
| 0 | Commit working tree | 0.1 |
| 1 | Reset schema from scratch | 1 |
| 2 | Item model + type classes | 1 |
| 3 | Importers::Index | 1 |
| 4 | Importers::TarkovDev | 1 |
| 5 | Importers::Market | 0.5 |
| 6 | Wiki parser + Importers::Wiki | 2 |
| 7 | Seeds orchestration + task graph | 1 |
| 8 | Public UI JSONB filters + type partials | 1 |
| 9 | Admin full edit | 1.5 |
| 10 | Full re-import + verification + CI | 1 |

**Total estimated: ~11 hours**