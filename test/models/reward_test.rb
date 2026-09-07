require "test_helper"

# == Schema Information
#
# Table name: rewards
#
#  id          :bigint           not null, primary key
#  task_id     :bigint           not null
#  reward_type :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_rewards_on_task_id  (task_id)
#
# Foreign Keys
#
#  fk_rails_...  (task_id => tasks.id)
#
class RewardTest < ActiveSupport::TestCase
  test "belongs to task and has unlock associations" do
    task = Task.create!(bsg_id: "rw-#{SecureRandom.hex(4)}", full_name: "Reward", name: "reward")
    reward = task.rewards.create!(reward_type: "Item")

    reward.loose_items.create!(item_name: "Loose", count: 2)
    reward.offer_unlocks.create!(item_name: "Offer", trader_name: "Prapor", trader_level: 1)
    reward.barter_unlocks.create!(item_name: "Barter")
    reward.craft_unlocks.create!(item_name: "Craft", hideout_station: "Workbench", station_level: 1)

    assert_equal task, reward.task
    assert_equal 1, reward.loose_items.count
    assert_equal 1, reward.offer_unlocks.count
    assert_equal 1, reward.barter_unlocks.count
    assert_equal 1, reward.craft_unlocks.count
  end
end
