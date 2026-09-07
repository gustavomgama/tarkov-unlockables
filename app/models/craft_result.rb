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
class CraftResult < ApplicationRecord
  belongs_to :craft_unlock
  has_many :craft_result_items, dependent: :destroy
end
