# == Schema Information
#
# Table name: craft_requirement_items
#
#  id                   :bigint           not null, primary key
#  craft_requirement_id :bigint           not null
#  item_id              :bigint
#  item_name            :string
#  count                :integer
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
# Indexes
#
#  index_craft_requirement_items_on_craft_requirement_id  (craft_requirement_id)
#  index_craft_requirement_items_on_item_id               (item_id)
#
# Foreign Keys
#
#  fk_rails_...  (craft_requirement_id => craft_requirements.id)
#  fk_rails_...  (item_id => items.id)
#
class CraftRequirementItem < ApplicationRecord
  belongs_to :craft_requirement
  belongs_to :item, optional: true
end
