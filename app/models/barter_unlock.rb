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
class BarterUnlock < ApplicationRecord
  belongs_to :reward
  belongs_to :item, optional: true
  has_many :barter_requirements, dependent: :destroy
  has_many :barter_results, dependent: :destroy
end
