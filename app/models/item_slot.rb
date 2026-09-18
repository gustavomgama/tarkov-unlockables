# == Schema Information
#
# Table name: item_slots
#
#  id         :bigint           not null, primary key
#  item_id    :bigint           not null
#  slot_id    :string
#  name_id    :string
#  name       :string
#  required   :boolean          default(FALSE), not null
#  position   :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_item_slots_on_item_id  (item_id)
#
# Foreign Keys
#
#  fk_rails_...  (item_id => items.id)
#
class ItemSlot < ApplicationRecord
  belongs_to :item
  has_many :item_slot_allowed_items, dependent: :destroy
end
