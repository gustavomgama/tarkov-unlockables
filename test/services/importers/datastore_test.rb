# frozen_string_literal: true

require "test_helper"

# The importer is the only thing that will ever write this data, and
# `db/seeds.rb` is not exercised by the suite, so it gets its own canonical
# fixture: two items, two tasks, every acquisition and reward branch.
class Importers::DatastoreTest < ActiveSupport::TestCase
  setup do
    @source = Rails.root.join("tmp/importers_datastore_test")
    FileUtils.rm_rf(@source)
    FileUtils.mkdir_p(@source)
  end

  teardown do
    FileUtils.rm_rf(@source)
  end

  def write(name, rows)
    File.write(@source.join("#{name}.ndjson"), rows.map { |row| JSON.generate(row) }.join("\n"))
  end

  def item_rows
    [
      {
        "bsg_id" => "w1", "slug" => "ak-74", "name" => "AK-74", "short_name" => "AK74",
        "properties_type" => "ItemPropertiesWeapon",
        "types" => %w[gun wearable],
        "categories" => { "leaves" => %w[assault-rifle weapon] },
        "handbook_categories" => { "leaves" => %w[assault-rifles] },
        "properties" => {
          "propertiesType" => "ItemPropertiesWeapon",
          "caliber" => "Caliber545x39", "allowedAmmo" => %w[a1], "stackMaxSize" => 60
        },
        "physical" => { "weight" => 3.5, "width" => 2, "height" => 1, "stack_max_size" => 1 },
        "contains_items" => [ { "bsg_id" => "a1", "name" => "5.45x39mm PS", "count" => 1 } ],
        "images" => { "icon" => "icon.png", "grid" => "grid.png", "base" => "base.png" },
        "links" => { "wiki" => "https://wiki/ak-74", "tarkovdev" => "https://tarkov.dev/ak-74",
                     "market" => "https://market/ak-74" },
        "wiki" => {
          "title" => "AK-74",
          "infobox" => { "type" => "Assault rifle", "caliber" => "5.45x39mm", "penetration" => "31" },
          "mod_slots" => [ { "slot" => "Stock", "items" => [] } ],
          "weapon_variants" => [ { "name" => "AK-74N" } ]
        },
        "acquisition" => {
          "buy" => [ { "trader_slug" => "prapor", "currency" => "RUB", "min_trader_level" => 2,
                       "task_unlock_id" => "t1", "price" => 12_345, "price_rub" => 12_345,
                       "buy_limit" => 5 } ],
          # Same offer again, plus one the index alone knows — deduped on import.
          "index_offers" => [
            { "trader_slug" => "prapor", "currency" => "RUB", "level" => "2" },
            { "trader_slug" => "fence", "currency" => "RUB", "level" => "1" }
          ],
          "barter" => [], "craft" => [], "task_rewards" => []
        }
      },
      {
        "bsg_id" => "a1", "slug" => "545-ps", "name" => "5.45x39mm PS", "short_name" => "PS",
        "properties_type" => "ItemPropertiesAmmo",
        "types" => %w[ammo],
        "categories" => { "leaves" => [] },
        "handbook_categories" => { "leaves" => %w[rounds] },
        "properties" => { "propertiesType" => "ItemPropertiesAmmo", "caliber" => "Caliber545x39",
                          "damage" => 54, "penetrationPower" => 31 },
        "contains_items" => [], "images" => {}, "links" => {},
        "wiki" => { "title" => "5.45x39mm PS",
                    "infobox" => { "type" => "Round", "penetration" => "31", "damage" => "99" },
                    "mod_slots" => [], "weapon_variants" => [] },
        "acquisition" => {
          "buy" => [], "index_offers" => [],
          "barter" => [ { "barter_id" => "b1", "trader_slug" => "prapor", "min_trader_level" => 2,
                          "buy_limit" => 3, "restock_amount" => 100, "task_unlock_id" => "t1",
                          "offered" => { "bsg_id" => "a1", "name" => "5.45x39mm PS", "count" => 1 },
                          "required" => [ { "bsg_id" => "w1", "name" => "AK-74", "count" => 2 } ] } ],
          "craft" => [ { "craft_id" => "c1", "station_name" => "Workbench", "level" => 2,
                         "duration" => 8200, "task_unlock_id" => nil,
                         "product" => { "bsg_id" => "a1", "name" => "5.45x39mm PS", "count" => 6 },
                         "required" => [ { "bsg_id" => "w1", "name" => "AK-74", "count" => 1,
                                           "is_tool" => true } ] } ],
          "task_rewards" => [ { "task_id" => "t1", "task_name" => "first-task" } ]
        }
      }
    ]
  end

  def task_rows
    [
      {
        "id" => "t1", "slug" => "first-task", "name" => "First Task",
        "wiki_link" => "https://wiki/first-task", "trader_slug" => "prapor",
        "map_id" => "map-customs", "map_name" => "Customs",
        "experience" => 12_345, "faction" => "BEAR",
        "kappa_required" => true, "lightkeeper_required" => false,
        "min_player_level" => 5,
        "trader_requirements" => [ { "trader_slug" => "prapor", "value" => 2 } ],
        "task_requirements" => [], "previous_tasks" => [],
        "needed_keys" => [
          { "map_id" => "map-shoreline", "map_name" => "Shoreline",
            "keys" => [ { "bsg_id" => "a1", "name" => "Dorm room 306 key" } ] }
        ],
        "objectives" => [
          { "id" => "o1", "type" => "giveItem", "description" => "Hand over 3 Salewa kits",
            "count" => 3, "optional" => false, "raw" => { "items" => [ "a1" ] } },
          { "id" => "o2", "type" => "visit", "description" => "Visit Customs",
            "count" => nil, "optional" => true },
          # A catch-all: 101 ids, skipped so it cannot swamp reverse usage.
          { "id" => "o3", "type" => "sellItem", "description" => "Sell any items",
            "count" => nil, "optional" => false,
            "raw" => { "items" => Array.new(101) { |i| "bulk-#{i}" } } }
        ],
        "leads_to" => [ { "task_id" => "", "task_name" => "second-task" } ],
        "start_rewards" => { "items" => [], "offer_unlock" => [], "barter_unlock" => [], "craft_unlock" => [] },
        "finish_rewards" => {
          "items" => [ { "bsg_id" => "a1", "name" => "5.45x39mm PS", "count" => 3 } ],
          "offer_unlock" => [ { "bsg_id" => "a1", "name" => "5.45x39mm PS", "trader_slug" => "prapor",
                                "level" => 3 } ],
          "barter_unlock" => [ { "trader_slug" => "prapor", "min_trader_level" => 2,
                                 "offered" => { "bsg_id" => "a1", "name" => "5.45x39mm PS" },
                                 "required" => [ { "bsg_id" => "w1", "name" => "AK-74", "count" => 1 } ] } ],
          "craft_unlock" => [ { "bsg_id" => "a1", "name" => "5.45x39mm PS",
                                "station_name" => "Workbench", "level" => 3 } ],
          "trader_standing" => [ { "trader_slug" => "prapor", "standing" => 0.15 } ],
          "skill_level_reward" => [ { "skill" => "Strength", "level" => 2 } ]
        }
      },
      {
        "id" => "t2", "slug" => "second-task", "name" => "Second Task",
        "wiki_link" => "", "trader_slug" => "therapist",
        "kappa_required" => false, "lightkeeper_required" => true,
        "min_player_level" => 0, "trader_requirements" => [],
        # The same prerequisite in both spellings: a hash and a bare id.
        "task_requirements" => [ { "bsg_id" => "t1", "name" => "First Task" } ],
        "previous_tasks" => %w[t1],
        "leads_to" => [ { "task_id" => "t1", "task_name" => "first-task" } ],
        "start_rewards" => { "items" => [], "offer_unlock" => [], "barter_unlock" => [], "craft_unlock" => [] },
        "finish_rewards" => { "items" => [], "offer_unlock" => [], "barter_unlock" => [], "craft_unlock" => [] }
      }
    ]
  end

  def import!
    write("items", item_rows)
    write("tasks", task_rows)
    write("hideout_stations", hideout_rows)
    write("traders", trader_rows)
    Importers::Datastore.import!(source: @source)
  end

  def trader_rows
    [
      {
        "id" => "tr1", "slug" => "prapor", "name" => "Prapor",
        "description" => "Warrant officer.", "currency" => "RUB",
        "image_url" => "https://assets/prapor.webp", "task_count" => 14,
        "levels" => [
          { "id" => "tr1-1", "level" => 1, "required_player_level" => 0,
            "required_reputation" => 0, "required_commerce" => 0,
            "pay_rate" => 0.4, "insurance_rate" => 0.21, "repair_cost_multiplier" => 3.8 },
          { "id" => "tr1-2", "level" => 2, "required_player_level" => 6,
            "required_reputation" => 0.7, "required_commerce" => 0,
            "pay_rate" => 0.4, "insurance_rate" => 0.2, "repair_cost_multiplier" => 3.75 }
        ]
      }
    ]
  end

  def hideout_rows
    [
      {
        "id" => "st1", "slug" => "workbench", "name" => "Workbench",
        "image_url" => "https://assets/workbench.png", "area_type" => 10,
        "levels" => [
          {
            "id" => "st1-1", "level" => 1, "construction_time" => 3600,
            "item_requirements" => [
              { "bsg_id" => "w1", "name" => "AK-74", "count" => 2, "found_in_raid" => true }
            ],
            "station_level_requirements" => [
              { "station_id" => "gen", "station_name" => "Generator", "level" => 1 }
            ],
            "trader_requirements" => [
              { "trader_id" => "mech", "trader_slug" => "mechanic", "level" => 2 }
            ]
          }
        ]
      }
    ]
  end

  test "imports the item universe and replaces whatever was there" do
    import!

    assert_equal 2, Item.count
    weapon = Item.find_by!(bsg_id: "w1")
    assert_equal "Item::Weapon", weapon.type
    assert_equal "AK-74", weapon.full_name
    assert_equal "AK-74", weapon.wiki_title
    assert_equal [ "https://wiki/ak-74", "https://tarkov.dev/ak-74", "https://market/ak-74" ], weapon.links
    assert_equal %w[icon.png grid.png base.png], weapon.images
  end

  # The API value wins over the wiki fallback: the app's CALIBER_MAP and
  # caliber filtering key on `Caliber545x39`, not on "5.45x39mm".
  test "keeps camelCase properties, their snake_case twins and the infobox fallback" do
    import!

    data = Item.find_by!(bsg_id: "w1").data
    assert_equal "Caliber545x39", data["caliber"]
    assert_equal "31", data["penetration"]
    assert_equal %w[a1], data["allowed_ammo"]
    assert_equal %w[a1], data["allowedAmmo"]
    assert_equal 60, data["stackMaxSize"]
    assert_equal [ { "slot" => "Stock", "items" => [] } ], data["mods"]
    assert_equal [ { "name" => "AK-74N" } ], data["weapon_variants"]
    assert_equal [ { "item" => "a1", "count" => 1 } ], data["containsItems"]

    # Physical facts ride along so the page can show weight and grid size.
    assert_equal 3.5, data["weight"]
    assert_equal [ 2, 1 ], [ data["width"], data["height"] ]

    ammo = Item.find_by!(bsg_id: "a1").data
    assert_equal 54, ammo["damage"]
    assert_equal "31", ammo["penetration"]
  end

  test "carries the item's caliber as a category so caliber filtering finds it" do
    import!

    categories = Item.find_by!(bsg_id: "w1").categories
    assert_includes categories, "assault_rifle"
    assert_includes categories, "assault_rifles"
    assert_includes categories, "5.45x39mm"
  end

  test "imports trader, barter, craft and task-reward routes" do
    import!

    weapon = Item.find_by!(bsg_id: "w1")
    assert_equal [ [ "Fence", "RUB", 1, false ], [ "Prapor", "RUB", 2, true ] ],
                 weapon.item_currencies.map { |c| [ c.trader, c.currency, c.min_trader_level, c.task_unlock ] }
                                     .sort_by { |c| c[2] }

    # The gated offer names its quest and carries its price; the index-only
    # offer has neither.
    gated = weapon.item_currencies.find_by!(task_unlock: true)
    assert_equal Task.find_by!(bsg_id: "t1").id, gated.task_id
    assert_equal "first-task", gated.task.name
    assert_equal [ 12_345, 12_345, 5 ], [ gated.price, gated.price_rub, gated.buy_limit ]

    index_only = weapon.item_currencies.find_by!(task_unlock: false)
    assert_nil index_only.task_id
    assert_nil index_only.price

    ammo = Item.find_by!(bsg_id: "a1")
    assert_equal [ [ "Prapor", "2", "5.45x39mm PS" ] ],
                 ammo.item_barters.map { |b| [ b.trader, b.trader_level, b.item_name ] }
    assert_equal [ [ "Workbench", 2 ] ], ammo.item_hideouts.map { |h| [ h.station, h.level ] }
    assert_equal [ "first-task" ], ammo.item_task_rewards.map(&:task_name)
    assert_equal Task.find_by!(bsg_id: "t1").id, ammo.item_task_rewards.first.task_id

    barter = ammo.item_barters.first
    assert_equal "b1", barter.barter_id
    assert_equal [ 3, 100 ], [ barter.buy_limit, barter.restock_amount ]
    assert_equal Task.find_by!(bsg_id: "t1").id, barter.task_id
    assert_equal [ [ "AK-74", 2 ] ],
                 barter.item_barter_requirements.map { |r| [ r.item_name, r.count ] }
    assert_equal Item.find_by!(bsg_id: "w1").id, barter.item_barter_requirements.first.item_id

    craft = ammo.item_hideouts.first
    assert_equal "c1", craft.craft_id
    assert_equal [ 6, 8200 ], [ craft.count, craft.duration ]
    assert_nil craft.task_id
    assert_equal [ [ "AK-74", 1, true ] ],
                 craft.item_hideout_requirements.map { |r| [ r.item_name, r.count, r.is_tool ] }
  end

  test "imports tasks and resolves the prerequisite graph by slug" do
    import!

    first = Task.find_by!(bsg_id: "t1")
    assert_equal "First Task", first.full_name
    assert_equal "first-task", first.name
    assert_equal "prapor", first.given_by
    assert_equal "map-customs", first.map_id
    assert_equal "Customs", first.map_name
    assert_equal 12_345, first.experience
    assert_equal "BEAR", first.faction

    key = first.needed_keys.sole
    assert_equal "Shoreline", key["map_name"]
    assert_equal "Dorm room 306 key", key["item_name"]
    assert_equal Item.find_by!(bsg_id: "a1").id, key["item_id"]
    assert first.kappa_required
    refute first.lightkeeper_required
    assert_equal "https://wiki/first-task", first.wiki_link

    second = Task.find_by!(bsg_id: "t2")
    assert second.lightkeeper_required
    assert_nil second.wiki_link
    assert_equal 1, second.leads_tos.count
    assert_equal first.id, second.leads_tos.first.follow_up_task_id
    assert_equal second.id, first.leads_tos.first.follow_up_task_id

    # task_requirements and previous_tasks are the same edge in two spellings.
    requirement = second.requirements.first
    assert_equal 1, requirement.previous_tasks.count
    assert_equal first.id, requirement.previous_tasks.first.task_id
    assert_equal "first-task", requirement.previous_tasks.first.task_name
    assert_equal 1, requirement.previous_tasks_count

    assert_equal 5, first.requirements.first.player_level
    assert_equal [ { "trader_name" => "prapor", "trader_level" => "2" } ],
                 first.requirements.first.trader_level

    # Objectives keep source order, count and the optional flag.
    assert_equal [ "Hand over 3 Salewa kits", "Visit Customs", "Sell any items" ],
                 first.task_objectives.map(&:description)
    assert_equal [ "giveItem", "visit", "sellItem" ], first.task_objectives.map(&:objective_type)
    assert_equal [ 3, nil, nil ], first.task_objectives.map(&:count)
    assert_equal [ false, true, false ], first.task_objectives.map(&:optional)
    assert_equal [ 0, 1, 2 ], first.task_objectives.map(&:position)

    hand_in = first.task_objectives.find_by!(objective_id: "o1")
    assert_equal [ "5.45x39mm PS" ], hand_in.task_objective_items.map(&:item_name)
    assert_equal Item.find_by!(bsg_id: "a1").id, hand_in.task_objective_items.first.item_id
    # The 101-id catch-all is skipped.
    assert_equal 0, first.task_objectives.find_by!(objective_id: "o3").task_objective_items.count
  end

  test "imports every reward kind" do
    import!

    finish = Task.find_by!(bsg_id: "t1").rewards.find_by!(reward_type: "finish_rewards")
    assert_equal [ [ "5.45x39mm PS", 3 ] ], finish.loose_items.map { |i| [ i.item_name, i.count ] }
    assert_equal [ [ "5.45x39mm PS", "Prapor", "3" ] ],
                 finish.offer_unlocks.map { |o| [ o.item_name, o.trader_name, o.trader_level ] }

    barter = finish.barter_unlocks.first
    assert_equal "5.45x39mm PS", barter.item_name
    assert_equal [ [ "Prapor", "2" ] ],
                 barter.barter_requirements.map { |r| [ r.trader_name, r.trader_level ] }
    assert_equal [ [ "AK-74", 1 ] ],
                 barter.barter_requirements.flat_map(&:barter_requirement_items)
                       .map { |i| [ i.item_name, i.count ] }
    assert_equal [ "5.45x39mm PS" ],
                 barter.barter_results.flat_map(&:barter_result_items).map(&:item_name)

    craft = finish.craft_unlocks.first
    assert_equal [ "5.45x39mm PS", "Workbench", 3 ],
                 [ craft.item_name, craft.hideout_station, craft.station_level ]

    # Unmodelled kinds ride along in jsonb; the modelled ones do not.
    assert_equal [ { "trader_slug" => "prapor", "standing" => 0.15 } ], finish.data["trader_standing"]
    assert_equal [ { "skill" => "Strength", "level" => 2 } ], finish.data["skill_level_reward"]
    refute finish.data.key?("items")

    assert_equal 2, Task.find_by!(bsg_id: "t1").rewards.count
  end

  test "imports hideout stations, levels and build costs" do
    import!

    station = HideoutStation.find_by!(slug: "workbench")
    assert_equal "Workbench", station.name
    assert_equal "https://assets/workbench.png", station.image_url

    level = station.hideout_levels.sole
    assert_equal [ 1, 3600 ], [ level.level, level.construction_time ]
    assert_equal [ { "station_name" => "Generator", "level" => 1 } ], level.station_requirements
    assert_equal [ { "name" => "Mechanic", "level" => 2 } ], level.trader_requirements

    req = level.hideout_item_requirements.sole
    assert_equal [ "AK-74", 2, true ], [ req.item_name, req.count, req.found_in_raid ]
    assert_equal Item.find_by!(bsg_id: "w1").id, req.item_id
  end

  test "imports traders and their loyalty levels" do
    import!

    trader = Trader.find_by!(slug: "prapor")
    assert_equal [ "Prapor", "RUB", 14 ], [ trader.name, trader.currency, trader.task_count ]
    assert_equal [ 1, 2 ], trader.trader_levels.map(&:level)

    ll2 = trader.trader_levels.last
    assert_equal [ 6, 0.7, 0.4 ], [ ll2.required_player_level, ll2.required_reputation, ll2.pay_rate ]
  end

  test "is idempotent — reseeding replaces rather than accumulates" do
    import!
    counts = [ Item.count, Task.count, ItemCurrency.count, ItemBarter.count,
               ItemHideout.count, ItemTaskReward.count, LeadsTo.count, Requirement.count,
               PreviousTask.count, Reward.count, LooseItem.count, OfferUnlock.count,
               BarterUnlock.count, CraftUnlock.count, ItemBarterRequirement.count,
               ItemHideoutRequirement.count, TaskObjective.count, TaskObjectiveItem.count,
               HideoutStation.count, HideoutLevel.count, HideoutItemRequirement.count,
               Trader.count, TraderLevel.count ]

    Importers::Datastore.import!(source: @source)

    assert_equal counts, [ Item.count, Task.count, ItemCurrency.count, ItemBarter.count,
                           ItemHideout.count, ItemTaskReward.count, LeadsTo.count, Requirement.count,
                           PreviousTask.count, Reward.count, LooseItem.count, OfferUnlock.count,
                           BarterUnlock.count, CraftUnlock.count, ItemBarterRequirement.count,
                           ItemHideoutRequirement.count, TaskObjective.count, TaskObjectiveItem.count,
                           HideoutStation.count, HideoutLevel.count, HideoutItemRequirement.count,
                           Trader.count, TraderLevel.count ]
  end
end
