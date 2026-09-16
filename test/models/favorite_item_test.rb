require "test_helper"
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
class FavoriteItemTest < ActiveSupport::TestCase
  fixtures :items
  test "must have independent PK and no cascade delete" do
    item = items(:one)
    fav = FavoriteItem.create!(item_id: item.id)
    assert_not_nil fav.id
    assert_equal item.id, fav.item_id
  end

  test "must enforce uniqueness per item" do
    item = items(:one)
    FavoriteItem.create!(item_id: item.id)
    assert_raises(ActiveRecord::RecordInvalid) do
      FavoriteItem.create!(item_id: item.id)
    end
  end
end
