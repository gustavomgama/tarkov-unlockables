require "test_helper"

# == Schema Information
#
# Table name: barter_unlocks
#
#  id         :bigint           not null, primary key
#  reward_id  :bigint           not null
#  item_id    :bigint
#  item_name  :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_barter_unlocks_on_item_id    (item_id)
#  index_barter_unlocks_on_reward_id  (reward_id)
#
# Foreign Keys
#
#  fk_rails_...  (item_id => items.id)
#  fk_rails_...  (reward_id => rewards.id)
#
class BarterUnlockTest < ActiveSupport::TestCase
  test "belongs to reward, item optional, has requirements and results" do
    task = Task.create!(bsg_id: "bu-#{SecureRandom.hex(4)}", full_name: "BU", name: "bu")
    reward = task.rewards.create!(reward_type: "Item")
    unlock = reward.barter_unlocks.create!(item_name: "Barter")

    unlock.barter_requirements.create!(trader_name: "Prapor", trader_level: "LL1")
    unlock.barter_results.create!

    assert_equal reward, unlock.reward
    assert_nil unlock.item
    assert_equal 1, unlock.barter_requirements.count
    assert_equal 1, unlock.barter_results.count
  end
end
