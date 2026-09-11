require "test_helper"

class FavoritesIntegrationTest < ActionDispatch::IntegrationTest
  def setup
    @item = Item.create!(bsg_id: "fav-int-#{SecureRandom.hex(4)}", full_name: "Integration Favorite", short_name: "IF")
  end

  def teardown
    FavoriteItem.destroy_all
    @item.destroy if @item
  rescue ActiveRecord::StatementInvalid
    # restrict delete may prevent destruction; ignore
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

  test "favorite independence: restrict delete prevents item deletion when favorite exists" do
    FavoriteItem.create!(item_id: @item.id)
    assert_raises(ActiveRecord::StatementInvalid) do
      @item.destroy
    end
  end
end
