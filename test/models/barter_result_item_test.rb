require "test_helper"

# == Schema Information
#
# Table name: barter_result_items
#
#  id               :bigint           not null, primary key
#  barter_result_id :bigint           not null
#  item_id          :bigint
#  item_name        :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_barter_result_items_on_barter_result_id  (barter_result_id)
#  index_barter_result_items_on_item_id           (item_id)
#
# Foreign Keys
#
#  fk_rails_...  (barter_result_id => barter_results.id)
#  fk_rails_...  (item_id => items.id)
#
class BarterResultItemTest < ActiveSupport::TestCase
  test "belongs to barter_result with optional item" do
    task = Task.create!(bsg_id: "bri2-#{SecureRandom.hex(4)}", full_name: "BRI2", name: "bri2")
    reward = task.rewards.create!(reward_type: "Item")
    unlock = reward.barter_unlocks.create!(item_name: "Barter")
    result = unlock.barter_results.create!

    item = result.barter_result_items.create!(item_name: "Result")
    assert_equal result, item.barter_result
    assert_nil item.item
  end
end
