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

  test "task_gated scope returns no records" do
    Item.create!(bsg_id: "tg-#{SecureRandom.hex(4)}", full_name: "Gated", short_name: "TG")
    assert_empty Item.task_gated
  end

  test "destroying an item destroys its obtain records" do
    item = Item.create!(bsg_id: "dep-#{SecureRandom.hex(4)}", full_name: "Dep", short_name: "D")
    item.item_currencies.create!(trader: "Prapor", currency: "RUB", min_trader_level: 1)
    item.item_hideouts.create!(station: "Workbench", level: 1)

    assert_difference([ "ItemCurrency.count", "ItemHideout.count" ], -1) { item.destroy }
  end
end
