require "test_helper"

# == Schema Information
#
# Table name: item_barters
#
#  id           :bigint           not null, primary key
#  item_id      :bigint           not null
#  trader       :string
#  trader_level :string
#  currency     :string
#  cost         :integer
#  item_name    :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_item_barters_on_item_id  (item_id)
#
# Foreign Keys
#
#  fk_rails_...  (item_id => items.id)
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
end
