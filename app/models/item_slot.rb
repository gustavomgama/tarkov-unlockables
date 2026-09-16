class ItemSlot < ApplicationRecord
  belongs_to :item
  has_many :item_slot_allowed_items, dependent: :destroy
end
