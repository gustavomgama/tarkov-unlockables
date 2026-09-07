# == Schema Information
#
# Table name: properties
#
#  id                :bigint           not null, primary key
#  item_id           :bigint
#  properties_type   :string
#  allowed_ammo      :text             default([]), is an Array
#  ammo_type         :string
#  armor_slots       :text             default([]), is an Array
#  armor_type        :string
#  base_item         :string
#  caliber           :string
#  armor_class       :integer
#  damage            :integer
#  default           :boolean
#  default_ammo      :string
#  default_preset    :string
#  penetration_power :integer
#  presets           :text             default([]), is an Array
#  slash_damage      :integer
#  stab_damage       :integer
#  category          :string
#  zones             :text             default([]), is an Array
#
# Indexes
#
#  index_properties_on_item_id  (item_id)
#
# Foreign Keys
#
#  fk_rails_...  (item_id => items.id)
#
class Property < ApplicationRecord
  belongs_to :item, foreign_key: :item_id
  has_many :slots, dependent: :destroy
end
