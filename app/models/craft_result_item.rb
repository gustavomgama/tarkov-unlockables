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
class CraftResultItem < ApplicationRecord
  belongs_to :craft_result
  belongs_to :item, optional: true
end
