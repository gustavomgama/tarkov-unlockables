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

  # The category filter is a no-op when the whole group is selected, and the
  # group is every category in the database. The test therefore seeds the group
  # itself: it cannot rely on the fixtures, because another test destroys every
  # item, which empties the category list and made this order-dependent (it
  # passed locally and failed in CI).
  test "filters that match nothing explain the filters" do
    first = create_item("Category One Item", categories: [ "zzqqxxone" ])
    second = create_item("Category Two Item", categories: [ "zzqqxxtwo" ])

    get items_url(filters: { category: [ "zzqqxxnothing" ] })

    assert_response :success
    assert_select "p", /No items match this combination of filters/
    assert_select "a", text: "Clear filters"
  ensure
    first&.destroy
    second&.destroy
  end
end
