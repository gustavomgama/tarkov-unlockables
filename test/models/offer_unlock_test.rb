require "test_helper"

# == Schema Information
#
# Table name: offer_unlocks
#
#  id           :bigint           not null, primary key
#  reward_id    :bigint           not null
#  item_id      :bigint
#  item_name    :string
#  trader_name  :string
#  trader_level :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_offer_unlocks_on_item_id    (item_id)
#  index_offer_unlocks_on_reward_id  (reward_id)
#
# Foreign Keys
#
#  fk_rails_...  (item_id => items.id)
#  fk_rails_...  (reward_id => rewards.id)
#
class OfferUnlockTest < ActiveSupport::TestCase
  test "belongs to reward with optional item" do
    task = Task.create!(bsg_id: "ou-#{SecureRandom.hex(4)}", full_name: "OU", name: "ou")
    reward = task.rewards.create!(reward_type: "Item")

    unlock = reward.offer_unlocks.create!(item_name: "Offer", trader_name: "Prapor", trader_level: 1)
    assert_equal reward, unlock.reward
    assert_nil unlock.item
  end
end
