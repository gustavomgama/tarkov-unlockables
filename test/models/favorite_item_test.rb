require "test_helper"
class FavoriteItemTest < ActiveSupport::TestCase
  test "must have independent PK and no cascade delete" do
    item = items(:one)
    fav = FavoriteItem.create!(item_id: item.id)
    assert_not_nil fav.id
    assert_equal item.id, fav.item_id
  end

  test "must enforce uniqueness per item" do
    item = items(:one)
    FavoriteItem.create!(item_id: item.id)
    assert_raises(ActiveRecord::RecordNotUnique) do
      FavoriteItem.create!(item_id: item.id)
    end
  end
end
