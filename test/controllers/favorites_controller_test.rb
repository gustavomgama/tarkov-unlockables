require "test_helper"

class FavoritesControllerTest < ActionDispatch::IntegrationTest
  include FavoritesTestSetup

  test "create adds favorite" do
    post favorites_url(item_id: @item.id)
    assert_response :redirect
    assert FavoriteItem.exists?(item_id: @item.id)
  end

  test "destroy removes favorite" do
    FavoriteItem.create!(item_id: @item.id)
    delete favorite_url(item_id: @item.id)
    assert_response :redirect
    assert_not FavoriteItem.exists?(item_id: @item.id)
  end

  test "index lists saved items" do
    FavoriteItem.create!(item_id: @item.id)

    get favorites_url

    assert_response :success
    assert_select "h1", text: "Favorites"
    assert_match @item.full_name, response.body
  end

  # The saved count and the card grid only render when something is saved; the
  # empty state is the other branch.
  test "index shows the saved count and the cards" do
    FavoriteItem.create!(item_id: @item.id)

    get favorites_url

    assert_response :success
    assert_select "p", text: /1 saved/
    assert_select ".card", minimum: 1
  end

  test "index shows the empty state when nothing is saved" do
    get favorites_url

    assert_response :success
    assert_select "p", text: "Nothing saved yet."
    assert_select ".card", count: 0
  end

  test "create an already-favorited item redirects with an alert" do
    FavoriteItem.create!(item_id: @item.id)

    post favorites_url(item_id: @item.id)

    assert_response :redirect
    assert_equal 1, FavoriteItem.where(item_id: @item.id).count
    assert_match(/Could not add favorite/, flash[:alert].to_s)
  end

  # Removing something that was never saved (a double click, a stale page) must
  # still redirect instead of raising on a nil record.
  test "destroying a favorite that is not saved still redirects" do
    assert_nil FavoriteItem.find_by(item_id: @item.id)

    delete favorite_url(item_id: @item.id)

    assert_response :redirect
    assert_match(/Removed from favorites/, flash[:notice].to_s)
  end
end
