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
class CraftUnlock < ApplicationRecord
  belongs_to :reward
  belongs_to :item, optional: true
  has_many :craft_requirements, dependent: :destroy
  has_many :craft_results, dependent: :destroy

  def self.ransackable_attributes(auth_object = nil)
    %w[item_name hideout_station]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[craft_requirements craft_results item reward]
  end
end
