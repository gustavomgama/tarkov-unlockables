# == Schema Information
#
# Table name: item_barter_requirements
#
#  id             :bigint           not null, primary key
#  item_barter_id :bigint           not null
#  item_id        :bigint
#  item_name      :string
#  count          :integer
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
# Indexes
#
#  index_item_barter_requirements_on_item_barter_id  (item_barter_id)
#  index_item_barter_requirements_on_item_id         (item_id)
#
# Foreign Keys
#
#  fk_rails_...  (item_barter_id => item_barters.id) ON DELETE => cascade
#  fk_rails_...  (item_id => items.id)
#
class ItemBarterRequirement < ApplicationRecord
  belongs_to :item_barter
  belongs_to :item, optional: true
end
