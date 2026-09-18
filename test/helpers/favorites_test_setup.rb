# The favorites controller and integration tests share the same item fixture
# and teardown.
module FavoritesTestSetup
  def setup
    @item = create_item("Favorite Test Item", short_name: "FTI")
  end

  def teardown
    FavoriteItem.destroy_all
    @item.destroy if @item
  end
end
