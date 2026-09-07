require "test_helper"

class ItemsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @item = Item.create!(bsg_id: "test123", full_name: "Test Item", short_name: "TI")
  end

  def teardown
    @item.destroy if @item
  end

  test "should get index" do
    get items_url
    assert_response :success
  end

  test "should get show" do
    get item_url(@item)
    assert_response :success
  end
end
