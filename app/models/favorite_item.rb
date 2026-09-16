# == Schema Information
#
# Table name: favorite_items
#
#  id         :bigint           not null, primary key
#  item_id    :bigint           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_favorite_items_on_item_id  (item_id)
#
# Foreign Keys
#
#  fk_rails_...  (item_id => items.id) ON DELETE => restrict
#
class FavoriteItem < ApplicationRecord
  belongs_to :item
  validates :item_id, presence: true, uniqueness: true
end
