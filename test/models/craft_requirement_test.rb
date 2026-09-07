require "test_helper"

# == Schema Information
#
# Table name: craft_requirements
#
#  id              :bigint           not null, primary key
#  craft_unlock_id :bigint           not null
#  trader_name     :string
#  trader_level    :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_craft_requirements_on_craft_unlock_id  (craft_unlock_id)
#
# Foreign Keys
#
#  fk_rails_...  (craft_unlock_id => craft_unlocks.id)
#
class CraftRequirementTest < ActiveSupport::TestCase
  test "belongs to craft_unlock and has requirement items" do
    task = Task.create!(bsg_id: "cr-#{SecureRandom.hex(4)}", full_name: "CR", name: "cr")
    reward = task.rewards.create!(reward_type: "Item")
    unlock = reward.craft_unlocks.create!(item_name: "Craft", hideout_station: "Workbench", station_level: 1)

    requirement = unlock.craft_requirements.create!(trader_name: "Prapor", trader_level: "LL1")
    requirement.craft_requirement_items.create!(item_name: "Req Item", count: 2)

    assert_equal unlock, requirement.craft_unlock
    assert_equal 1, requirement.craft_requirement_items.count
  end
end
