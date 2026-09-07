require "test_helper"

# == Schema Information
#
# Table name: craft_results
#
#  id              :bigint           not null, primary key
#  craft_unlock_id :bigint           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_craft_results_on_craft_unlock_id  (craft_unlock_id)
#
# Foreign Keys
#
#  fk_rails_...  (craft_unlock_id => craft_unlocks.id)
#
class CraftResultTest < ActiveSupport::TestCase
  test "belongs to craft_unlock and has result items" do
    task = Task.create!(bsg_id: "cres-#{SecureRandom.hex(4)}", full_name: "CRES", name: "cres")
    reward = task.rewards.create!(reward_type: "Item")
    unlock = reward.craft_unlocks.create!(item_name: "Craft", hideout_station: "Workbench", station_level: 1)

    result = unlock.craft_results.create!
    result.craft_result_items.create!(item_name: "Result")

    assert_equal unlock, result.craft_unlock
    assert_equal 1, result.craft_result_items.count
  end
end
