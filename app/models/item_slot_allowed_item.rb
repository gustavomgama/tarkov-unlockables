class ItemSlotAllowedItem < ApplicationRecord
  belongs_to :item_slot
  belongs_to :item, optional: true
end
