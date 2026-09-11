class FavoriteItem < ApplicationRecord
  belongs_to :item
  validates :item_id, presence: true, uniqueness: true
end
