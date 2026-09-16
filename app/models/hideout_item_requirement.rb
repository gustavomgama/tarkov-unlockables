# == Schema Information
#
# Table name: hideout_item_requirements
#
#  id               :bigint           not null, primary key
#  hideout_level_id :bigint           not null
#  item_id          :bigint
#  item_name        :string
#  count            :integer
#  found_in_raid    :boolean          default(FALSE), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_hideout_item_requirements_on_hideout_level_id  (hideout_level_id)
#  index_hideout_item_requirements_on_item_id           (item_id)
#
# Foreign Keys
#
#  fk_rails_...  (hideout_level_id => hideout_levels.id)
#  fk_rails_...  (item_id => items.id)
#
class HideoutItemRequirement < ApplicationRecord
  belongs_to :hideout_level
  belongs_to :item, optional: true
end
