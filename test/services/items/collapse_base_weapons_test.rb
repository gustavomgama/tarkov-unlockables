require "test_helper"

class Items::CollapseBaseWeaponsTest < ActiveSupport::TestCase
  test "promotes the default preset, merges data, retargets references, deletes base" do
    base = Item::Weapon.create!(
      bsg_id: "collapse-base-1", slug: "velociraptor", full_name: "Velociraptor", short_name: "Velo",
      categories: [ "gun" ],
      data: { "ergonomics" => 55, "recoil" => 120, "mods" => [ "suppressor" ], "caliber" => "Caliber300Blackout" }
    )
    preset = Item::Generic.create!(
      bsg_id: "collapse-preset-1", slug: "velociraptor-default", full_name: "Velociraptor Default", short_name: "Velo D",
      categories: [ "preset", "weapon" ],
      data: { "base_item" => base.bsg_id, "default" => true, "types" => [ "preset" ],
              "caliber" => ".300 Blackout", "categories" => [ "5448e54d" ], "containsItems" => [ { "item" => base.bsg_id } ] }
    )
    task = Task.create!(bsg_id: "collapse-task-1", name: "collapse-task", full_name: "Collapse Task", given_by: "Mechanic")
    reward = task.rewards.create!(reward_type: "finish_rewards")
    offer = base.offer_unlocks.create!(
      item_name: "Velociraptor", trader_name: "mechanic", trader_level: "4", reward: reward
    )
    base.loose_items.create!(item_name: "Velociraptor", count: 1, reward: reward)
    barter_unlock = base.barter_unlocks.create!(item_name: "Velociraptor", reward: reward)
    barter_result_item = base.barter_result_items.create!(item_name: "Velociraptor", barter_result: barter_unlock.barter_results.create!)
    base.item_currencies.create!(trader: "Mechanic", currency: "EUR", min_trader_level: 3, task_unlock: false)

    Items::CollapseBaseWeapons.call([ base.id ])

    assert_not Item.exists?(base.id)
    preset = Item.unscoped.find(preset.id)
    assert_equal "Item::Weapon", preset.type
    assert_equal 55, preset.data["ergonomics"]
    assert_equal 120, preset.data["recoil"]
    assert_equal [ "suppressor" ], preset.data["mods"]
    # preset identity keys survive the merge
    assert_equal base.bsg_id, preset.data["base_item"]
    assert_equal true, preset.data["default"]
    assert_equal ".300 Blackout", preset.data["caliber"]
    assert_equal [ "preset", "weapon" ], preset.categories
    # references retargeted to the promoted preset
    assert_equal preset.id, offer.reload.item_id
    assert_equal preset.id, LooseItem.find_by(item_name: "Velociraptor").item_id
    assert_equal preset.id, barter_unlock.reload.item_id
    assert_equal preset.id, barter_result_item.reload.item_id
    assert_equal [ "Mechanic" ], preset.item_currencies.pluck(:trader)
  ensure
    LooseItem.where(item_name: "Velociraptor").destroy_all
    OfferUnlock.where(item_name: "Velociraptor").destroy_all
    BarterResultItem.where(item_name: "Velociraptor").destroy_all
    BarterUnlock.where(item_name: "Velociraptor").destroy_all
    ItemCurrency.where(trader: "Mechanic", currency: "EUR").destroy_all
    Item.unscoped.where(bsg_id: [ "collapse-base-1", "collapse-preset-1" ]).destroy_all
    task&.destroy
  end

  test "does not duplicate currencies already present on the preset" do
    base = Item::Weapon.create!(
      bsg_id: "collapse-base-2", slug: "ash12", full_name: "ASh-12", short_name: "ASh",
      data: {}
    )
    preset = Item::Generic.create!(
      bsg_id: "collapse-preset-2", slug: "ash12-default", full_name: "ASh-12 Default", short_name: "ASh D",
      data: { "base_item" => base.bsg_id, "default" => true, "types" => [ "preset" ] }
    )
    base.item_currencies.create!(trader: "Prapor", currency: "RUB", min_trader_level: 4, task_unlock: false)
    preset.item_currencies.create!(trader: "Prapor", currency: "RUB", min_trader_level: 4, task_unlock: false)

    Items::CollapseBaseWeapons.call([ base.id ])

    assert_equal 1, Item.unscoped.find(preset.id).item_currencies.count
  ensure
    ItemCurrency.joins(:item).where(items: { bsg_id: [ "collapse-base-2", "collapse-preset-2" ] }).delete_all
    Item.unscoped.where(bsg_id: [ "collapse-base-2", "collapse-preset-2" ]).destroy_all
  end

  test "is idempotent — base rows already collapsed are skipped" do
    assert_nothing_raised do
      Items::CollapseBaseWeapons.call([ 999_999_001 ])
    end
  end

  test "auto-scope collapses every base weapon referenced by a default preset" do
    base = Item::Weapon.create!(
      bsg_id: "collapse-base-4", slug: "auto-gun", full_name: "Auto Gun", short_name: "AG",
      data: { "ergonomics" => 40 }
    )
    preset = Item::Generic.create!(
      bsg_id: "collapse-preset-4", slug: "auto-gun-default", full_name: "Auto Gun Default", short_name: "AG D",
      data: { "base_item" => base.bsg_id, "default" => true, "types" => [ "preset" ] }
    )

    Items::CollapseBaseWeapons.call

    assert_not Item.exists?(base.id)
    assert_equal "Item::Weapon", Item.unscoped.find(preset.id).type
    assert_equal 40, Item.unscoped.find(preset.id).data["ergonomics"]
  ensure
    Item.unscoped.where(bsg_id: [ "collapse-base-4", "collapse-preset-4" ]).destroy_all
  end

  test "leaves base weapons without a default preset untouched" do
    base = Item::Weapon.create!(
      bsg_id: "collapse-base-3", slug: "m4a1", full_name: "M4A1", short_name: "M4",
      data: { "ergonomics" => 60 }
    )

    Items::CollapseBaseWeapons.call([ base.id ])

    assert Item.exists?(base.id)
    assert_equal "Item::Weapon", base.reload.type
    assert_equal 60, base.reload.data["ergonomics"]
  end
end
