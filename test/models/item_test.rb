require "test_helper"

# == Schema Information
#
# Table name: items
#
#  id          :bigint           not null, primary key
#  type        :string           default("Item::Generic"), not null
#  bsg_id      :string
#  slug        :string
#  full_name   :string
#  short_name  :string
#  wiki_title  :string
#  categories  :text             default([]), is an Array
#  links       :text             default([]), is an Array
#  images      :text             default([]), is an Array
#  data        :jsonb            not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  search_text :string           default(""), not null
#
# Indexes
#
#  index_items_on_bsg_id            (bsg_id) UNIQUE
#  index_items_on_categories        (categories) USING gin
#  index_items_on_data              (data) USING gin
#  index_items_on_full_name         (full_name)
#  index_items_on_search_text_trgm  (search_text) USING gin
#  index_items_on_slug              (slug)
#  index_items_on_type              (type)
#
class ItemTest < ActiveSupport::TestCase
  STI_CLASSES = [
    Item::Weapon, Item::Ammo, Item::Armor, Item::Key, Item::Magazine,
    Item::Container, Item::Medical, Item::Provision, Item::Throwable, Item::Generic
  ].freeze

  fixtures :all

  test "defaults to Item::Generic type" do
    item = create_item("Generic", short_name: "G")
    assert_equal "Item::Generic", item.type
    assert_instance_of Item::Generic, Item.find(item.id)
  end

  test "has the four obtain associations" do
    item = create_item("Obtainable")

    {
      item_currencies: { trader: "Prapor", currency: "RUB", min_trader_level: 1 },
      item_task_rewards: { task_name: "Debut" },
      item_hideouts: { station: "Workbench", level: 1 },
      item_barters: { trader: "Prapor", trader_level: "LL1", currency: "RUB", cost: 100, item_name: "Barter" }
    }.each do |association, attrs|
      item.public_send(association).create!(attrs)
      assert_equal 1, item.public_send(association).count
    end
  end

  test "destroying an item destroys its obtain records" do
    item = create_item("Dep", short_name: "D")
    item.item_currencies.create!(trader: "Prapor", currency: "RUB", min_trader_level: 1)
    item.item_hideouts.create!(station: "Workbench", level: 1)

    assert_difference([ "ItemCurrency.count", "ItemHideout.count" ], -1) { item.destroy }
  end

  # barter/craft unlocks are not leaves: their requirements/results and those
  # rows' items hang off them, so the destroy has to walk the whole chain. Using
  # `delete_all` here skipped it and the restrict FKs rejected the item delete.
  test "destroying an item cascades through its barter and craft unlock graphs" do
    models = %w[
      BarterUnlock BarterRequirement BarterRequirementItem BarterResult BarterResultItem
      CraftUnlock CraftRequirement CraftRequirementItem CraftResult CraftResultItem
      OfferUnlock ItemBarter LooseItem ItemTaskReward ItemCurrency ItemHideout
    ].map(&:constantize)
    before = models.index_with(&:count)

    items(:one).destroy!

    after = models.index_with(&:count)
    assert_equal before.keys, after.keys
    before.each do |model, count|
      assert_operator after[model], :<, count, "#{model} should lose the rows that hung off the item"
    end
  end

  # Mirror of the task-graph test: an item appears in many reference columns (as
  # a barter/craft requirement or result item, a loose item, a favorite, an
  # item_task_reward). Deleting every fixture item proves each edge has a
  # handler, so the admin Delete action cannot 500 on an item mid-graph.
  test "every fixture item can be destroyed with the graph attached" do
    Item.all.to_a.each(&:destroy!)

    assert_equal 0, Item.count
  end

  # --- type_for mappings ---

  test "type_for maps source properties_type suffixes to type classes" do
    {
      "ItemPropertiesWeapon" => Item::Weapon,
      "ItemPropertiesAmmo" => Item::Ammo,
      "ItemPropertiesArmor" => Item::Armor,
      "ItemPropertiesKey" => Item::Key,
      "ItemPropertiesMagazine" => Item::Magazine,
      "ItemPropertiesContainer" => Item::Container,
      "ItemPropertiesMedKit" => Item::Medical,
      "ItemPropertiesFoodDrink" => Item::Provision,
      "ItemPropertiesGrenade" => Item::Throwable
    }.each do |properties_type, expected|
      assert_equal expected, Item.type_for(properties_type, nil)
    end
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
    STI_CLASSES.each do |klass|
      assert klass.new.is_a?(Item), "#{klass} is not an Item"
      assert_equal klass.name, klass.sti_name
    end
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

  # --- unlock logic (uses internal id) ---

  test "requires_task? is true when an unlock references the item" do
    assert items(:one).requires_task?
  end

  test "requires_task? is false when no unlock references the item" do
    item = create_item("No Task", short_name: "NT")
    refute item.requires_task?
  end

  test "task_gated scope returns items referenced by unlocks" do
    gated_ids = Item.task_gated.pluck(:id)

    assert_includes gated_ids, items(:one).id
    assert_includes gated_ids, items(:two).id
  end

  # 101 offers in the source carry a taskUnlock, so an item whose only gate is a
  # trader offer has to count as task-gated — the filter used to miss it.
  test "a trader offer is task-gated only when it carries the task flag" do
    { true => true, false => false }.each do |task_unlock, expected|
      item = create_item("Offer #{task_unlock}", short_name: "O#{task_unlock}")
      item.item_currencies.create!(trader: "Prapor", currency: "RUB", min_trader_level: 1,
                                   task_unlock: task_unlock)

      assert_equal expected, item.requires_task?
      assert_equal expected, Item.task_gated.exists?(item.id)
    ensure
      item&.destroy
    end
  end

  # The items index counts per caliber and groups by class on every cold
  # filter-options pass; the jsonb GIN index cannot serve `->>` equality, so
  # without these expression indexes each was a sequential scan (measured on the
  # real dataset: 349ms of SQL → 27ms).
  test "the caliber and class expressions are indexed" do
    indexes = ActiveRecord::Base.connection.indexes(:items).map(&:name)

    assert_includes indexes, "index_items_on_data_caliber"
    assert_includes indexes, "index_items_on_data_class"
  end

  test "type_for resolves the source property type and lets the wiki infobox win" do
    assert_equal Item::Weapon, Item.type_for("ItemPropertiesWeapon")
    assert_equal Item::Medical, Item.type_for("ItemPropertiesMedKit")
    assert_equal Item::Generic, Item.type_for("ItemPropertiesSomethingNew")
    # The wiki infobox is authoritative when both sources are present.
    assert_equal Item::Armor, Item.type_for("ItemPropertiesWeapon", "Armor")
  end

  test "caliber_display maps the source enum and passes unknown values through" do
    assert_equal "5.56x45mm NATO", Item.caliber_display("Caliber556x45NATO")
    assert_equal "12/70", Item.caliber_display("Caliber12g")
    assert_equal "5.45x39mm", Item.caliber_display("5.45x39mm")
    assert_nil Item.caliber_display(nil)
  end

  # --- guarded edges: partial import data must degrade, not raise ---
  test "ammo_packs is empty for an item with no bsg_id" do
    assert_equal 0, Item.new(full_name: "No BSG").ammo_packs.count
  end

  # The packs query binds a JSON string against a jsonb column, so it only works
  # because Postgres infers the parameter's type from the left operand. Nothing
  # else exercises the matching path (the view only renders when it matches).
  test "ammo_packs finds the packs whose containsItems name the item" do
    round = create_item("Packed Round", data: {})
    pack = create_item("Round Pack", data: { "containsItems" => [ { "item" => round.bsg_id, "count" => 2 } ] })
    create_item("Unrelated Pack", data: { "containsItems" => [ { "item" => "someone-else" } ] })

    assert_equal [ pack.id ], round.ammo_packs.pluck(:id)
  end

  test "caliber_ammo is empty for an item with no caliber" do
    item = create_item("No Caliber", data: {})

    assert_equal 0, item.caliber_ammo.count
  ensure
    item&.destroy
  end

  # The item belongs in its own caliber list: the page renders that list with
  # `current: @item` and highlights the row, so excluding self would hide the
  # round the visitor is looking at.
  test "caliber_ammo lists the item among its caliber and orders by penetration" do
    own = create_item("Own Round", klass: Item::Ammo, data: { "caliber" => "TestCal", "penetration_power" => 20 })
    stronger = create_item("Stronger Round", klass: Item::Ammo, data: { "caliber" => "TestCal", "penetration_power" => 40 })
    other = create_item("Other Round", klass: Item::Ammo, data: { "caliber" => "OtherCal", "penetration_power" => 60 })

    assert_equal [ stronger.id, own.id ], own.caliber_ammo.pluck(:id)
    refute_includes own.caliber_ammo.pluck(:id), other.id
  ensure
    Item.where(id: [ own&.id, stronger&.id, other&.id ]).delete_all
  end

  # The caliber map has to survive both shapes the import can leave behind: a
  # raw value that was never translated out of the BSG enum, and two raw values
  # that resolve to the same display.
  test "caliber_category_map skips an enum-shaped display and a repeated display" do
    unmapped = create_item("Unmapped Caliber", klass: Item::Ammo, data: { "caliber" => "CaliberNotMapped" })
    from_enum = create_item("Enum Caliber", klass: Item::Ammo, data: { "caliber" => "Caliber545x39" })
    from_display = create_item("Display Caliber", klass: Item::Ammo, data: { "caliber" => "5.45x39mm" })

    map = Item.build_caliber_category_map

    refute_includes map.keys, "CaliberNotMapped"
    assert_includes map.keys, "5.45x39mm"
  ensure
    [ unmapped, from_enum, from_display ].each { |item| item&.destroy }
  end

  # --- stats_partial (Task 8) ---

  test "stats_partial returns demodulized class-name partial path" do
    STI_CLASSES.each do |klass|
      assert_equal "items/#{klass.name.demodulize.underscore}_stats", klass.new.stats_partial
    end
  end

  # --- search ---

  test "search matches slug, full_name, and short_name" do
    [ "item-one", "Test Item One", "TIO" ].each do |query|
      assert_includes Item.search(query).map(&:id), items(:one).id, query
    end
  end

  test "search with blank query returns all" do
    assert_equal Item.count, Item.search("").count
    assert_equal Item.count, Item.search(nil).count
  end
end
