# == Schema Information
#
# Table name: loose_items
#
#  id         :bigint           not null, primary key
#  reward_id  :bigint           not null
#  item_id    :bigint
#  item_name  :string
#  count      :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_loose_items_on_item_id    (item_id)
#  index_loose_items_on_reward_id  (reward_id)
#
# Foreign Keys
#
#  fk_rails_...  (item_id => items.id)
#  fk_rails_...  (reward_id => rewards.id)
#
class LooseItem < ApplicationRecord
  belongs_to :reward
  belongs_to :item, optional: true
end
