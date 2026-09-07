require "test_helper"

# == Schema Information
#
# Table name: item_currencies
#
#  id               :bigint           not null, primary key
#  item_id          :bigint           not null
#  trader           :string
#  currency         :string
#  min_trader_level :integer
#  task_unlock      :boolean          default(FALSE), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_item_currencies_on_item_id  (item_id)
#
# Foreign Keys
#
#  fk_rails_...  (item_id => items.id)
#
class ItemCurrencyTest < ActiveSupport::TestCase
  test "belongs to item" do
    item = Item.create!(bsg_id: "ic-#{SecureRandom.hex(4)}", full_name: "IC", short_name: "IC")
    ic = item.item_currencies.create!(trader: "Prapor", currency: "RUB", min_trader_level: 1)
    assert_equal item, ic.item
  end

  test "requires an item" do
    assert_raises(ActiveRecord::RecordInvalid) do
      ItemCurrency.create!(trader: "Prapor", currency: "RUB", min_trader_level: 1)
    end
  end
end
