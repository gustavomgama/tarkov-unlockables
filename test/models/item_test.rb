require "test_helper"

# == Schema Information
#
# Table name: items
#
#  id         :bigint           not null, primary key
#  type       :string           default("Item::Generic"), not null
#  bsg_id     :string
#  slug       :string
#  full_name  :string
#  short_name :string
#  wiki_title :string
#  categories :text             default([]), is an Array
#  links      :text             default([]), is an Array
#  images     :text             default([]), is an Array
#  data       :jsonb            not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_items_on_bsg_id  (bsg_id) UNIQUE
#  index_items_on_slug    (slug)
#  index_items_on_type    (type)
#
class ItemTest < ActiveSupport::TestCase
  fixtures :all

  test "defaults to Item::Generic type" do
    item = Item.create!(bsg_id: "gen-#{SecureRandom.hex(4)}", full_name: "Generic", short_name: "G")
    assert_equal "Item::Generic", item.type
    assert_instance_of Item::Generic, Item.find(item.id)
  end

  test "has the four obtain associations" do
    item = Item.create!(bsg_id: "obtain-#{SecureRandom.hex(4)}", full_name: "Obtainable", short_name: "O")

    item.item_currencies.create!(trader: "Prapor", currency: "RUB", min_trader_level: 1)
    item.item_task_rewards.create!(task_name: "Debut")
    item.item_hideouts.create!(station: "Workbench", level: 1)
    item.item_barters.create!(trader: "Prapor", trader_level: "LL1", currency: "RUB", cost: 100, item_name: "Barter")

    assert_equal 1, item.item_currencies.count
    assert_equal 1, item.item_task_rewards.count
    assert_equal 1, item.item_hideouts.count
    assert_equal 1, item.item_barters.count
  end

  test "destroying an item destroys its obtain records" do
    item = Item.create!(bsg_id: "dep-#{SecureRandom.hex(4)}", full_name: "Dep", short_name: "D")
    item.item_currencies.create!(trader: "Prapor", currency: "RUB", min_trader_level: 1)
    item.item_hideouts.create!(station: "Workbench", level: 1)

    assert_difference([ "ItemCurrency.count", "ItemHideout.count" ], -1) { item.destroy }
  end

  # --- type_for mappings ---

  test "type_for maps source properties_type suffixes to type classes" do
    assert_equal Item::Weapon, Item.type_for("ItemPropertiesWeapon", nil)
    assert_equal Item::Ammo, Item.type_for("ItemPropertiesAmmo", nil)
    assert_equal Item::Armor, Item.type_for("ItemPropertiesArmor", nil)
    assert_equal Item::Key, Item.type_for("ItemPropertiesKey", nil)
    assert_equal Item::Magazine, Item.type_for("ItemPropertiesMagazine", nil)
    assert_equal Item::Container, Item.type_for("ItemPropertiesContainer", nil)
    assert_equal Item::Medical, Item.type_for("ItemPropertiesMedKit", nil)
    assert_equal Item::Provision, Item.type_for("ItemPropertiesFoodDrink", nil)
    assert_equal Item::Throwable, Item.type_for("ItemPropertiesGrenade", nil)
  end

  test "type_for falls back to Generic for unknown types" do
    assert_equal Item::Generic, Item.type_for("ItemPropertiesUnknown", nil)
    assert_equal Item::Generic, Item.type_for(nil, nil)
  end

  test "type_for wiki infobox overrides source type" do
    assert_equal Item::Weapon, Item.type_for("ItemPropertiesWeapon", "weapon")
  end

  test "type_for accepts class-name keys" do
    assert_equal Item::Medical, Item.type_for("Medical", nil)
    assert_equal Item::Provision, Item.type_for("Provision", nil)
    assert_equal Item::Throwable, Item.type_for("Throwable", nil)
  end

  # --- STI ---

  test "type classes are Items with correct sti_name" do
    assert Item::Weapon.new.is_a?(Item)
    assert_equal "Item::Weapon", Item::Weapon.sti_name
    assert_equal "Item::Ammo", Item::Ammo.sti_name
    assert_equal "Item::Armor", Item::Armor.sti_name
    assert_equal "Item::Key", Item::Key.sti_name
    assert_equal "Item::Magazine", Item::Magazine.sti_name
    assert_equal "Item::Container", Item::Container.sti_name
    assert_equal "Item::Medical", Item::Medical.sti_name
    assert_equal "Item::Provision", Item::Provision.sti_name
    assert_equal "Item::Throwable", Item::Throwable.sti_name
    assert_equal "Item::Generic", Item::Generic.sti_name
  end

  # --- data= setter ---

  test "data= accepts a JSON string and stores a hash" do
    item = Item.new(bsg_id: "data-json-#{SecureRandom.hex(4)}", full_name: "Data", short_name: "D")
    item.data = '{"caliber": "5.45x39mm"}'
    assert_equal({ "caliber" => "5.45x39mm" }, item.data)
  end

  test "data= accepts a Hash directly" do
    item = Item.new(bsg_id: "data-hash-#{SecureRandom.hex(4)}", full_name: "Data", short_name: "D")
    item.data = { "caliber" => "5.45x39mm" }
    assert_equal({ "caliber" => "5.45x39mm" }, item.data)
  end

  test "data= with invalid JSON adds an error and stores empty hash" do
    item = Item.new(bsg_id: "data-bad-#{SecureRandom.hex(4)}", full_name: "Data", short_name: "D")
    item.data = "{not valid json"
    assert item.errors[:data].any?
    assert_equal({}, item.data)
  end

  # --- obtain graph (uses internal id) ---

  test "obtain_from returns entries from all obtain associations" do
    item = items(:one)
    types = item.obtain_types
    assert_includes types, :task_reward
    assert_includes types, :hideout
    assert_includes types, :barter
    assert_includes types, :currency
  end

  test "obtain_from_* filters by type" do
    item = items(:one)
    assert_equal 1, item.obtain_from_tasks.size
    assert_equal 1, item.obtain_from_hideouts.size
    assert_equal 1, item.obtain_from_barters.size
    assert_equal 1, item.obtain_from_currencies.size
  end

  # --- unlock logic (uses internal id) ---

  test "requires_task? is true when an unlock references the item" do
    assert items(:one).requires_task?
  end

  test "requires_task? is false when no unlock references the item" do
    item = Item.create!(bsg_id: "notask-#{SecureRandom.hex(4)}", full_name: "No Task", short_name: "NT")
    refute item.requires_task?
  end

  test "task_gated scope returns items referenced by unlocks" do
    gated = Item.task_gated
    assert_includes gated.map(&:id), items(:one).id
    assert_includes gated.map(&:id), items(:two).id
  end

  test "how_to_unlock returns unlock paths" do
    paths = items(:one).how_to_unlock
    assert paths.any?
    assert paths.all? { |p| p.respond_to?(:task) && p.respond_to?(:reward_type) && p.respond_to?(:unlock_method) }
  end

  test "unlock_details_for returns offer unlock details" do
    path = items(:one).how_to_unlock.find { |p| p.unlock_method == :offer_unlock }
    assert path
    details = items(:one).unlock_details_for(path)
    assert_match(/Prapor LL2/, details)
  end

  test "unlock_details_for returns craft unlock details" do
    path = items(:one).how_to_unlock.find { |p| p.unlock_method == :craft_unlock }
    assert path
    details = items(:one).unlock_details_for(path)
    assert_match(/Craft at Workbench Level 1/, details)
    assert_match(/Test Item One x2/, details)
  end

  test "unlock_details_for returns barter unlock details" do
    path = items(:one).how_to_unlock.find { |p| p.unlock_method == :barter_unlock }
    assert path
    details = items(:one).unlock_details_for(path)
    assert_match(/Prapor LL2/, details)
    assert_match(/Gives: Test Item One/, details)
    assert_match(/Test Item One x2/, details)
  end

  # --- search ---

  test "search matches slug, full_name, and short_name" do
    assert_includes Item.search("item-one").map(&:id), items(:one).id
    assert_includes Item.search("Test Item One").map(&:id), items(:one).id
    assert_includes Item.search("TIO").map(&:id), items(:one).id
  end

  test "search with blank query returns all" do
    assert_equal Item.count, Item.search("").count
    assert_equal Item.count, Item.search(nil).count
  end
end
