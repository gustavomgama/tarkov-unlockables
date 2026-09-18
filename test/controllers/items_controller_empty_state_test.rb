require "test_helper"

# The index names why a result set is empty and offers the one action that
# undoes it. Each of the three branches was uncovered.
class ItemsControllerEmptyStateTest < ActionDispatch::IntegrationTest
  def setup
    @item = create_item("Empty State Item")
  end

  def teardown
    @item&.destroy
  end

  test "a page past the end explains the page and links back to page 1" do
    get items_url(page: 999)

    assert_response :success
    assert_select "p", /past the end of the list/
    assert_select "a", text: "Back to page 1"
  end

  test "a search with no matches explains the search" do
    get items_url(q: "zzqqxxnothing")

    assert_response :success
    assert_select "p", /No items match this search/
    assert_select "a", text: "Show all items"
  end

  test "filters that match nothing explain the filters" do
    get items_url(filters: { category: [ "zzqqxxnothing" ] })

    assert_response :success
    assert_select "p", /No items match this combination of filters/
    assert_select "a", text: "Clear filters"
  end
end
