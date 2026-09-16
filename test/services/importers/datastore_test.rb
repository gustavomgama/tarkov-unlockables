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
                       "task_unlock_id" => "t1" } ],
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
          "barter" => [ { "trader_slug" => "prapor", "min_trader_level" => 2,
                          "offered" => { "bsg_id" => "a1", "name" => "5.45x39mm PS", "count" => 1 },
                          "required" => [ { "bsg_id" => "w1", "name" => "AK-74", "count" => 2 } ] } ],
          "craft" => [ { "station_name" => "Workbench", "level" => 2 } ],
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
        "kappa_required" => true, "lightkeeper_required" => false,
        "min_player_level" => 5,
        "trader_requirements" => [ { "trader_slug" => "prapor", "value" => 2 } ],
        "task_requirements" => [], "previous_tasks" => [],
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
                                "station_name" => "Workbench", "level" => 3 } ]
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
    Importers::Datastore.import!(source: @source)
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

    # The gated offer names its quest; the index-only offer has no task.
    gated = weapon.item_currencies.find_by!(task_unlock: true)
    assert_equal Task.find_by!(bsg_id: "t1").id, gated.task_id
    assert_equal "first-task", gated.task.name
    assert_nil weapon.item_currencies.find_by!(task_unlock: false).task_id

    ammo = Item.find_by!(bsg_id: "a1")
    assert_equal [ [ "Prapor", "2", "5.45x39mm PS" ] ],
                 ammo.item_barters.map { |b| [ b.trader, b.trader_level, b.item_name ] }
    assert_equal [ [ "Workbench", 2 ] ], ammo.item_hideouts.map { |h| [ h.station, h.level ] }
    assert_equal [ "first-task" ], ammo.item_task_rewards.map(&:task_name)
    assert_equal Task.find_by!(bsg_id: "t1").id, ammo.item_task_rewards.first.task_id
  end

  test "imports tasks and resolves the prerequisite graph by slug" do
    import!

    first = Task.find_by!(bsg_id: "t1")
    assert_equal "First Task", first.full_name
    assert_equal "first-task", first.name
    assert_equal "prapor", first.given_by
    assert_equal "map-customs", first.map_id
    assert_equal "Customs", first.map_name
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

    assert_equal 2, Task.find_by!(bsg_id: "t1").rewards.count
  end

  test "is idempotent — reseeding replaces rather than accumulates" do
    import!
    counts = [ Item.count, Task.count, ItemCurrency.count, ItemBarter.count,
               ItemHideout.count, ItemTaskReward.count, LeadsTo.count, Requirement.count,
               PreviousTask.count, Reward.count, LooseItem.count, OfferUnlock.count,
               BarterUnlock.count, CraftUnlock.count ]

    Importers::Datastore.import!(source: @source)

    assert_equal counts, [ Item.count, Task.count, ItemCurrency.count, ItemBarter.count,
                           ItemHideout.count, ItemTaskReward.count, LeadsTo.count, Requirement.count,
                           PreviousTask.count, Reward.count, LooseItem.count, OfferUnlock.count,
                           BarterUnlock.count, CraftUnlock.count ]
  end
end
