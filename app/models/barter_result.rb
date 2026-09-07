# == Schema Information
#
# Table name: barter_results
#
#  id               :bigint           not null, primary key
#  barter_unlock_id :bigint           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_barter_results_on_barter_unlock_id  (barter_unlock_id)
#
# Foreign Keys
#
#  fk_rails_...  (barter_unlock_id => barter_unlocks.id)
#
class BarterResult < ApplicationRecord
  belongs_to :barter_unlock
  has_many :barter_result_items, dependent: :destroy
end
