# == Schema Information
#
# Table name: item_hideout_requirements
#
#  id              :bigint           not null, primary key
#  item_hideout_id :bigint           not null
#  item_id         :bigint
#  item_name       :string
#  count           :integer
#  is_tool         :boolean          default(FALSE), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_item_hideout_requirements_on_item_hideout_id  (item_hideout_id)
#  index_item_hideout_requirements_on_item_id          (item_id)
#
# Foreign Keys
#
#  fk_rails_...  (item_hideout_id => item_hideouts.id) ON DELETE => cascade
#  fk_rails_...  (item_id => items.id)
#
class ItemHideoutRequirement < ApplicationRecord
  belongs_to :item_hideout
  belongs_to :item, optional: true
end
