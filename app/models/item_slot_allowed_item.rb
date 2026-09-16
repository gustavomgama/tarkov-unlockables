# == Schema Information
#
# Table name: item_slot_allowed_items
#
#  id           :bigint           not null, primary key
#  item_slot_id :bigint           not null
#  item_id      :bigint
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_item_slot_allowed_items_on_item_id       (item_id)
#  index_item_slot_allowed_items_on_item_slot_id  (item_slot_id)
#
# Foreign Keys
#
#  fk_rails_...  (item_id => items.id)
#  fk_rails_...  (item_slot_id => item_slots.id) ON DELETE => cascade
#
class ItemSlotAllowedItem < ApplicationRecord
  belongs_to :item_slot
  belongs_to :item, optional: true
end
