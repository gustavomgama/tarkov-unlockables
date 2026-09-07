require "test_helper"

# == Schema Information
#
# Table name: craft_result_items
#
#  id              :bigint           not null, primary key
#  craft_result_id :bigint           not null
#  item_id         :bigint
#  item_name       :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_craft_result_items_on_craft_result_id  (craft_result_id)
#  index_craft_result_items_on_item_id          (item_id)
#
# Foreign Keys
#
#  fk_rails_...  (craft_result_id => craft_results.id)
#  fk_rails_...  (item_id => items.id)
#
class CraftResultItemTest < ActiveSupport::TestCase
  test "belongs to craft_result with optional item" do
    task = Task.create!(bsg_id: "cri2-#{SecureRandom.hex(4)}", full_name: "CRI2", name: "cri2")
    reward = task.rewards.create!(reward_type: "Item")
    unlock = reward.craft_unlocks.create!(item_name: "Craft", hideout_station: "Workbench", station_level: 1)
    result = unlock.craft_results.create!

    item = result.craft_result_items.create!(item_name: "Result")
    assert_equal result, item.craft_result
    assert_nil item.item
  end
end
