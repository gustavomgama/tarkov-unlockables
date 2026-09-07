require "test_helper"

# == Schema Information
#
# Table name: barter_requirements
#
#  id               :bigint           not null, primary key
#  barter_unlock_id :bigint           not null
#  trader_name      :string
#  trader_level     :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_barter_requirements_on_barter_unlock_id  (barter_unlock_id)
#
# Foreign Keys
#
#  fk_rails_...  (barter_unlock_id => barter_unlocks.id)
#
class BarterRequirementTest < ActiveSupport::TestCase
  test "belongs to barter_unlock and has requirement items" do
    task = Task.create!(bsg_id: "br-#{SecureRandom.hex(4)}", full_name: "BR", name: "br")
    reward = task.rewards.create!(reward_type: "Item")
    unlock = reward.barter_unlocks.create!(item_name: "Barter")

    requirement = unlock.barter_requirements.create!(trader_name: "Prapor", trader_level: "LL1")
    requirement.barter_requirement_items.create!(item_name: "Req Item", count: 2)

    assert_equal unlock, requirement.barter_unlock
    assert_equal 1, requirement.barter_requirement_items.count
  end
end
