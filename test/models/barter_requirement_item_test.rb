require "test_helper"

# == Schema Information
#
# Table name: barter_requirement_items
#
#  id                    :bigint           not null, primary key
#  barter_requirement_id :bigint           not null
#  item_id               :bigint
#  item_name             :string
#  count                 :integer
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#
# Indexes
#
#  index_barter_requirement_items_on_barter_requirement_id  (barter_requirement_id)
#  index_barter_requirement_items_on_item_id                (item_id)
#
# Foreign Keys
#
#  fk_rails_...  (barter_requirement_id => barter_requirements.id)
#  fk_rails_...  (item_id => items.id)
#
class BarterRequirementItemTest < ActiveSupport::TestCase
  test "belongs to barter_requirement with optional item" do
    task = Task.create!(bsg_id: "bri-#{SecureRandom.hex(4)}", full_name: "BRI", name: "bri")
    reward = task.rewards.create!(reward_type: "Item")
    unlock = reward.barter_unlocks.create!(item_name: "Barter")
    requirement = unlock.barter_requirements.create!(trader_name: "Prapor", trader_level: "LL1")

    item = requirement.barter_requirement_items.create!(item_name: "Req", count: 1)
    assert_equal requirement, item.barter_requirement
    assert_nil item.item
  end
end
