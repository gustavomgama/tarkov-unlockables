require "test_helper"
class FavoriteItemTest < ActiveSupport::TestCase
  fixtures :items
  test "favorite has its own primary key and points at the item" do
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

  # The validation above is a check-then-insert: two concurrent requests both
  # pass it. Only the unique index stops the second row, so prove the database
  # rejects a duplicate even when validations are skipped.
  test "database rejects a duplicate item_id without validations" do
    item = items(:one)
    FavoriteItem.create!(item_id: item.id)
    assert_raises(ActiveRecord::RecordNotUnique) do
      FavoriteItem.insert_all!([ { item_id: item.id, created_at: Time.current, updated_at: Time.current } ])
    end
  end

  # favorite_items.item_id is `on_delete: :restrict`, so a favorited item is
  # undeletable unless Item owns the association: the admin delete action 500s.
  test "destroying an item deletes its favorite" do
    item = items(:one)
    FavoriteItem.create!(item_id: item.id)

    assert_difference("FavoriteItem.count", -1) { item.destroy }

    assert_not FavoriteItem.exists?(item_id: item.id)
  end
end
