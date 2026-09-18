require "test_helper"

# == Schema Information
#
# Table name: item_barters
#
#  id             :bigint           not null, primary key
#  item_id        :bigint           not null
#  trader         :string
#  trader_level   :string
#  currency       :string
#  cost           :integer
#  item_name      :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  barter_id      :string
#  count          :integer          default(1), not null
#  buy_limit      :integer
#  restock_amount :bigint
#  task_id        :bigint
#
# Indexes
#
#  index_item_barters_on_barter_id  (barter_id)
#  index_item_barters_on_item_id    (item_id)
#  index_item_barters_on_task_id    (task_id)
#
# Foreign Keys
#
#  fk_rails_...  (item_id => items.id)
#  fk_rails_...  (task_id => tasks.id)
#
class ItemBarterTest < ActiveSupport::TestCase
  test "belongs to item" do
    item = Item.create!(bsg_id: "ib-#{SecureRandom.hex(4)}", full_name: "IB", short_name: "IB")
    ib = item.item_barters.create!(trader: "Prapor", trader_level: "LL1", currency: "RUB", cost: 100, item_name: "Barter")
    assert_equal item, ib.item
  end

  test "requires an item" do
    assert_raises(ActiveRecord::RecordInvalid) do
      ItemBarter.create!(trader: "Prapor", trader_level: "LL1", currency: "RUB", cost: 100, item_name: "Barter")
    end
  end

  test "destroying the item takes the barter and its requirements with it" do
    item = Item.create!(bsg_id: "cb-#{SecureRandom.hex(4)}", full_name: "Cascade Barter", short_name: "CB")
    input = Item.create!(bsg_id: "cb-in-#{SecureRandom.hex(4)}", full_name: "Input", short_name: "IN")
    barter = item.item_barters.create!(trader: "Prapor", trader_level: "LL1")
    barter.item_barter_requirements.create!(item: input, item_name: "Input", count: 1)

    # Item uses delete_all, so the FK cascade has to clean the requirements.
    item.destroy!

    assert_equal 0, ItemBarter.where(id: barter.id).count
    assert_equal 0, ItemBarterRequirement.where(item_barter_id: barter.id).count
  ensure
    input&.destroy
  end
end
