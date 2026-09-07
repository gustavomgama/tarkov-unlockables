# == Schema Information
#
# Table name: barter_requirement_items
#
#  id                    :bigint           not null, primary key
#  barter_requirement_id :bigint           not null
#  item_id               :bigint
#  item_name             :string
#  count                 :integer
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#
# Indexes
#
#  index_barter_requirement_items_on_barter_requirement_id  (barter_requirement_id)
#  index_barter_requirement_items_on_item_id                (item_id)
#
# Foreign Keys
#
#  fk_rails_...  (barter_requirement_id => barter_requirements.id)
#  fk_rails_...  (item_id => items.id)
#
class BarterRequirementItem < ApplicationRecord
  belongs_to :barter_requirement
  belongs_to :item, optional: true
end
