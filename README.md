# Tarkov Unlockables

System for easy access to unlockables and where and how to get any buyable, craftable or barteable items focusing on task-gated items.

Answering questions like:
- how do I unlock CBJs?
- what are the armor class 5 I can get or unlock?
- What loyalty level is required for me to buy salewas?
- Is there magazine case barters or buyable offers, can I even buy them, how do I unlock offers?

## Setup

```bash
bundle install
rails db:create db:migrate db:seed
```

## Run with Docker (development)

```bash
docker compose up --build
```

Open `http://localhost:3000`. First boot installs gems, runs
`db:prepare` (create + migrate), then starts Puma with live reload
(code is bind-mounted, gems cached in a volume).

Seed separately — the dev DB starts empty:

```bash
docker compose exec web bin/rails db:seed
```

Stop with `docker compose down`. Wipe the dev DB with
`docker compose down -v`.

## Run with Docker (production)

Needs only Docker Engine. The app serves on port 80 inside the image
(Thruster in front of Puma); first boot migrates and seeds automatically.

```bash
# Postgres (once)
docker network create tarkov-net
docker run -d --name tarkov-db-postgres --network tarkov-net \
  -e POSTGRES_PASSWORD=secret -e POSTGRES_DB=tarkov_db_prod postgres:18

# Build (once, rebuild after code changes)
docker build -t tarkov-db .

# Run
docker run -d --name tarkov-db --network tarkov-net -p 3000:80 \
  -e DATABASE_URL=postgres://postgres:secret@tarkov-db-postgres:5432/tarkov_db_prod \
  -e RAILS_MASTER_KEY=$(cat config/master.key) \
  -e ADMIN_PASSWORD=changeme \
  tarkov-db

curl localhost:3000/up   # 200 when ready (first boot takes ~1 min: seed import)
```

Open `http://localhost:3000`. Stop with
`docker stop tarkov-db tarkov-db-postgres`.

## CI

```bash
bin/ci                      # full pipeline (mirrors GitHub Actions)
bundle exec rake ci:quick   # security + lint only
```

Single source of truth: `lib/tasks/ci.rake`. CI also rehearses the Render
deploy — builds the production image, migrates, boots, hits `/up` —
against postgres:18, matching Neon production.

## Deploy

- Render + Neon: `render.yaml` blueprint (needs `DATABASE_URL`,
  `RAILS_MASTER_KEY`, `ADMIN_PASSWORD`).
- VPS: Kamal via `config/deploy.yml` (`kamal setup`, then `kamal deploy`).

Seed data lives in `offlinedata/` (`parsed_items.json` is tracked because
`db:seed` needs it); regenerate it with `rake wiki:parse`.

## Queries

### Items

```ruby
# All items
Item.count

# Find item by bsg_id
Item.find_by(bsg_id: "5448ba0b4bdc2d02308b456c")

# Find item by name (partial match)
Item.where("full_name ILIKE ?", "%salewa%")

# Items by category
Item.where("categories @> ?", ["meds"])

# Items with properties
Item.joins(:property).count

# Item properties
item = Item.find_by(bsg_id: "544fb45d4bdc2dee738b4568")
item.property
item.property.slots

# Item slots
item.property.slots.each do |slot|
  slot.name_id
  slot.allowed_items
  slot.allowed_categories
end

# Item obtain methods
item.item_task_rewards
item.item_hideouts
item.item_barters
item.item_currencies
```

### Properties

```ruby
# Items by armor class
Property.where(armor_class: "5")
Property.where(armor_class: "6")

# Items by caliber
Property.where(caliber: "Caliber556x45NATO")

# Ammo types
Property.where(properties_type: "ItemPropertiesAmmo")

# Weapons with slots
Property.where.not(slots: {id: nil}).joins(:slots)

# Med kits
Property.where(properties_type: "ItemPropertiesMedKit")

# Food/drink
Property.where(properties_type: "ItemPropertiesFoodDrink")
```

### Tasks

```ruby
# All tasks
Task.count

# Find task by bsg_id
Task.find_by(bsg_id: "5ae4493d86f7744b8e15aa8f")

# Find task by name
Task.find_by(name: "a-big-loss")

# Tasks given by trader
Task.where(given_by: "therapist")
Task.where(given_by: "prapor")
Task.where(given_by: "mechanic")
Task.where(given_by: "skier")
Task.where(given_by: "peacekeeper")
Task.where(given_by: "ragman")
Task.where(given_by: "jaeger")

# Tasks requiring kappa
Task.where(kappa_required: true)

# Tasks with level requirement
Task.joins(:requirements).where("requirements.player_level > ?", 20)

# Task requirements
task = Task.find_by(name: "a-big-loss")
task.requirements
task.requirements.first.player_level

# Task rewards
task.rewards.where(reward_type: "finish_rewards")
task.rewards.flat_map(&:loose_items)
task.rewards.flat_map(&:offer_unlocks)
task.rewards.flat_map(&:barter_unlocks)
task.rewards.flat_map(&:craft_unlocks)

# Tasks leading to another task
task.leads_tos
task.leads_tos.map(&:follow_up_task)
```

### Task Rewards

```ruby
# All rewards
Reward.count

# Rewards by type
Reward.where(reward_type: "start_rewards")
Reward.where(reward_type: "finish_rewards")

# Rewards containing specific item
loose = Reward.joins(:loose_items).where(loose_items: {item_id: "544fb45d4bdc2dee738b4568"})
offer = Reward.joins(:offer_unlocks).where(offer_unlocks: {item_id: "544fb45d4bdc2dee738b4568"})

# Loose items
loose_item = LooseItem.find_by(item_id: "5449016a4bdc2d6f028b456f")
loose_item.reward
loose_item.reward.task

# Offer unlocks (trader purchases)
offer_unlock = OfferUnlock.find_by(item_id: "5448be9a4bdc2dfd2f8b456a")
offer_unlock.reward.task
offer_unlock.trader_name
offer_unlock.trader_level
```

### Barter Unlocks

```ruby
# All barter unlocks
BarterUnlock.count

# Find barters for an item
BarterUnlock.joins(:reward).where(barter_unlocks: {item_id: "545cdae64bdc2d39198b4568"})

# Barter requirements
barter = BarterUnlock.first
barter.barter_requirements
barter.barter_requirements.first.barter_requirement_items
barter.barter_results.first.barter_result_items

# Items that can be obtained via barter
BarterUnlock.pluck(:item_id).uniq
```

### Craft Unlocks

```ruby
# All craft unlocks
CraftUnlock.count

# Find crafts for an item
CraftUnlock.joins(:reward).where(craft_unlocks: {item_id: "59fafb5d86f774067a6f2084"})

# Craft requirements
craft = CraftUnlock.first
craft.craft_requirements
craft.craft_requirements.first.craft_requirement_items
craft.craft_results.first.craft_result_items

# Hideout station crafts
CraftUnlock.where(hideout_station: "Workbench")
CraftUnlock.where(hideout_station: "Medstation")
CraftUnlock.where(hideout_station: "Lavatory")
CraftUnlock.where(hideout_station: "Nutrition unit")

# Station level requirements
CraftUnlock.where(station_level: 3)
```

### Trader Levels

```ruby
# Items buyable from a trader at specific level
ItemBarter.where(trader_name: "therapist", trader_level: 1)
ItemCurrency.where(trader_name: "prapor", trader_level: 3)

# All trader offers for an item
item = Item.find_by(bsg_id: "544fb45d4bdc2dee738b4568")
item.item_barters
item.item_currencies

# Trader levels for an item
item.item_barters.pluck(:trader_name, :trader_level)
item.item_currencies.pluck(:trader_name, :trader_level, :currency)
```

### Hideout

```ruby
# Items available from hideout
ItemHideout.where(station_name: "Medstation")
ItemHideout.where(station_name: "Workbench")
ItemHideout.where(station_name: "Lavatory")

# Items by station level
ItemHideout.where(station_level: 1)
ItemHideout.where(station_level: 2)
ItemHideout.where(station_level: 3)

# Hideout crafts
CraftUnlock.where.not(hideout_station: nil)
```

### Example Queries

```ruby
# =============================================
# TASK-GATED ITEMS - How to unlock specific items
# =============================================

# HOW TO UNLOCK - shows the task chain needed (not just WHERE, but WHICH TASK)
item = Item.find_by("full_name ILIKE ?", "%M80A1%")
item.how_to_unlock.each do |path|
  puts "Task: #{path.task.name}"
  puts "  Reward type: #{path.reward_type}"       # start_rewards or finish_rewards
  puts "  Unlock method: #{path.unlock_method}"   # task_reward, offer_unlock, barter_unlock, craft_unlock, loose_item
end

# WHERE TO GET - shows direct obtain methods (not task chain)
item.obtain_from          # all methods: task reward, hideout, barter, currency
item.obtain_from_tasks    # task rewards only
item.obtain_from_hideouts # hideout crafts only
item.obtain_from_barters  # barters only
item.obtain_from_currencies # trader purchases only

# What task unlocks the offer/barter/craft for an item?
item = Item.find_by("full_name ILIKE ?", "%item name%")
item.how_to_unlock.each do |path|
  puts "#{path.task.name} (#{path.unlock_method})"
end

# Full unlock path with task chain - what tasks do I need to complete?
item = Item.find_by("full_name ILIKE ?", "%M80A1%")
item.how_to_unlock.each do |path|
  puts "Complete: #{path.task.name}"
  path.task.prerequisite_chain[1..].each do |t|
    puts "  -> #{t[:name]} (#{t[:given_by]}) - Level #{t[:level]}"
  end
end

# =============================================
# ARMOR CLASS QUERIES
# =============================================

# What armor class 5 armors can I get?
Item.joins(:property).where("properties.armor_class = 5")

# All armors by class
Item.joins(:property).where("properties.armor_class = 6")  # Class 6 armors
Item.joins(:property).where("properties.armor_class = 4")  # Class 4 armors

# =============================================
# BUY/BARTER/UNLOCK OFFERS
# =============================================

# Is there magazine case barters or buyable offers?
mc = Item.find_by("full_name ILIKE ?", "%magazine case%")
mc.obtain_from_barters    # barters for it
mc.obtain_from_currencies # buyable with currency
mc.obtain_from_tasks      # task rewards

# What loyalty level required to buy item?
item = Item.find_by("full_name ILIKE ?", "%Salewa%")
item.item_barters.pluck(:trader_name, :trader_level)
item.item_currencies.pluck(:trader_name, :trader_level, :currency)

# What items can I get at loyalty level 2 from Therapist?
Item.joins(:item_barters).where(item_barters: {trader_name: "therapist", trader_level: 2})

# =============================================
# TASK REWARDS
# =============================================

# Find all tasks that give specific item as reward
item_id = "544fb45d4bdc2dee738b4568"
Reward.joins(:loose_items).where(loose_items: {item_id: item_id})
Reward.joins(:offer_unlocks).where(offer_unlocks: {item_id: item_id})
Reward.joins(:barter_unlocks).where(barter_unlocks: {item_id: item_id})
Reward.joins(:craft_unlocks).where(craft_unlocks: {item_id: item_id})

# All tasks that unlock a specific item
Task.joins(rewards: :offer_unlocks).where(offer_unlocks: {item_id: item_id})
Task.joins(rewards: :barter_unlocks).where(barter_unlocks: {item_id: item_id})
Task.joins(rewards: :craft_unlocks).where(craft_unlocks: {item_id: item_id})

# =============================================
# ITEMS REQUIRING TASKS
# =============================================

# All items that require a task to unlock trade/barter/craft
Item.task_gated

# Does this item require a task?
item = Item.find_by("full_name ILIKE ?", "%Salewa%")
item.requires_task?  # true/false

# Non-task-gated items (direct purchase/craft)
Item.where.not(id: Item.task_gated.select(:id))

# Filter by task requirement
Item.where("full_name ILIKE ?", "%item%").select { |i| i.requires_task? }
```
