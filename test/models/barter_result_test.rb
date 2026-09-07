require "test_helper"

# == Schema Information
#
# Table name: barter_results
#
#  id               :bigint           not null, primary key
#  barter_unlock_id :bigint           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_barter_results_on_barter_unlock_id  (barter_unlock_id)
#
# Foreign Keys
#
#  fk_rails_...  (barter_unlock_id => barter_unlocks.id)
#
class BarterResultTest < ActiveSupport::TestCase
  test "belongs to barter_unlock and has result items" do
    task = Task.create!(bsg_id: "bres-#{SecureRandom.hex(4)}", full_name: "BRES", name: "bres")
    reward = task.rewards.create!(reward_type: "Item")
    unlock = reward.barter_unlocks.create!(item_name: "Barter")

    result = unlock.barter_results.create!
    result.barter_result_items.create!(item_name: "Result")

    assert_equal unlock, result.barter_unlock
    assert_equal 1, result.barter_result_items.count
  end
end
