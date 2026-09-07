require "test_helper"

# == Schema Information
#
# Table name: craft_unlocks
#
#  id              :bigint           not null, primary key
#  reward_id       :bigint           not null
#  item_id         :bigint
#  item_name       :string
#  hideout_station :string
#  station_level   :integer
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_craft_unlocks_on_item_id    (item_id)
#  index_craft_unlocks_on_reward_id  (reward_id)
#
# Foreign Keys
#
#  fk_rails_...  (item_id => items.id)
#  fk_rails_...  (reward_id => rewards.id)
#
class CraftUnlockTest < ActiveSupport::TestCase
  test "belongs to reward, item optional, has requirements and results" do
    task = Task.create!(bsg_id: "cu-#{SecureRandom.hex(4)}", full_name: "CU", name: "cu")
    reward = task.rewards.create!(reward_type: "Item")
    unlock = reward.craft_unlocks.create!(item_name: "Craft", hideout_station: "Workbench", station_level: 1)

    unlock.craft_requirements.create!(trader_name: "Prapor", trader_level: "LL1")
    unlock.craft_results.create!

    assert_equal reward, unlock.reward
    assert_nil unlock.item
    assert_equal 1, unlock.craft_requirements.count
    assert_equal 1, unlock.craft_results.count
  end
end
