# == Schema Information
#
# Table name: craft_requirements
#
#  id              :bigint           not null, primary key
#  craft_unlock_id :bigint           not null
#  trader_name     :string
#  trader_level    :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_craft_requirements_on_craft_unlock_id  (craft_unlock_id)
#
# Foreign Keys
#
#  fk_rails_...  (craft_unlock_id => craft_unlocks.id)
#
class CraftRequirement < ApplicationRecord
  belongs_to :craft_unlock
  has_many :craft_requirement_items, dependent: :destroy
end
