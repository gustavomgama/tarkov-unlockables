require "test_helper"

# == Schema Information
#
# Table name: craft_requirement_items
#
#  id                   :bigint           not null, primary key
#  craft_requirement_id :bigint           not null
#  item_id              :bigint
#  item_name            :string
#  count                :integer
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
# Indexes
#
#  index_craft_requirement_items_on_craft_requirement_id  (craft_requirement_id)
#  index_craft_requirement_items_on_item_id               (item_id)
#
# Foreign Keys
#
#  fk_rails_...  (craft_requirement_id => craft_requirements.id)
#  fk_rails_...  (item_id => items.id)
#
class CraftRequirementItemTest < ActiveSupport::TestCase
  test "belongs to craft_requirement with optional item" do
    task = Task.create!(bsg_id: "cri-#{SecureRandom.hex(4)}", full_name: "CRI", name: "cri")
    reward = task.rewards.create!(reward_type: "Item")
    unlock = reward.craft_unlocks.create!(item_name: "Craft", hideout_station: "Workbench", station_level: 1)
    requirement = unlock.craft_requirements.create!(trader_name: "Prapor", trader_level: "LL1")

    item = requirement.craft_requirement_items.create!(item_name: "Req", count: 1)
    assert_equal requirement, item.craft_requirement
    assert_nil item.item
  end
end
