# == Schema Information
#
# Table name: barter_result_items
#
#  id               :bigint           not null, primary key
#  barter_result_id :bigint           not null
#  item_id          :bigint
#  item_name        :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_barter_result_items_on_barter_result_id  (barter_result_id)
#  index_barter_result_items_on_item_id           (item_id)
#
# Foreign Keys
#
#  fk_rails_...  (barter_result_id => barter_results.id)
#  fk_rails_...  (item_id => items.id)
#
class BarterResultItem < ApplicationRecord
  belongs_to :barter_result
  belongs_to :item, optional: true
end
