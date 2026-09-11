require "test_helper"

class FavoritesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @item = Item.create!(bsg_id: "fav-test-#{SecureRandom.hex(4)}", full_name: "Favorite Test Item", short_name: "FTI")
  end

  def teardown
    FavoriteItem.destroy_all
    @item.destroy if @item
  end

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
end
