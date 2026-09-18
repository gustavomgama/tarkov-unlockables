require "test_helper"

class FavoritesIntegrationTest < ActionDispatch::IntegrationTest
  include FavoritesTestSetup

  # The toggle reads the saved state: "Add" before, "Remove" after.
  test "the item page toggle reflects the saved state" do
    get item_url(@item)
    assert_select "form[action=?]", favorites_path(item_id: @item.id) do
      assert_select "button", text: /Add favorite/
    end

    FavoriteItem.create!(item_id: @item.id)

    get item_url(@item)
    assert_select "form[action=?]", favorite_path(item_id: @item.id) do
      assert_select "button", text: /Remove favorite/
    end
  end

  test "add and remove favorite via buttons" do
    get item_url(@item)
    assert_response :success

    post favorites_url(item_id: @item.id)
    assert_response :redirect
    assert FavoriteItem.exists?(item_id: @item.id)

    delete favorite_url(item_id: @item.id)
    assert_response :redirect
    assert_not FavoriteItem.exists?(item_id: @item.id)
  end

  # favorite_items.item_id is `on_delete: :restrict`, so nothing can orphan a
  # favorite through raw SQL. Item owns the association (`dependent: :delete_all`),
  # so a normal destroy removes the favorite instead of hitting that FK — which
  # is what the old behaviour did, 500ing the admin Delete action for every
  # favorited item and forcing a rescue in this suite's teardown.
  test "deleting an item removes its favorite instead of raising" do
    FavoriteItem.create!(item_id: @item.id)

    @item.destroy!

    assert_not FavoriteItem.exists?(item_id: @item.id)
  end
end
