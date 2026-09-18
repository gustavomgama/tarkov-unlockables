require "test_helper"

# ItemsController#index pagination: page selection, the per_page widening, and
# the disabled ends of the range. The Ruby-only coverage metric does not see
# view branches, so these assert the rendered controls.
class ItemsControllerPaginationTest < ActionDispatch::IntegrationTest
  test "index paginates and disables the ends of the range" do
    25.times { |i| create_item(format("Paged Item %02d", i)) }

    get items_url
    assert_response :success
    assert_select "nav[aria-label=Pagination]" do
      assert_select "span", text: /Page 1 of 2/
      assert_select "a[aria-disabled=\"true\"]", text: "« First"
      assert_select "a[aria-disabled=\"true\"]", text: "← Previous"
      assert_select "a", text: "Next →"
    end

    get items_url(page: 2)
    assert_response :success
    assert_select "span", text: /Page 2 of 2/
    assert_select "a[aria-disabled=\"true\"]", text: "Next →"
    assert_select "a", text: "← Previous"
  end

  # The controls are computed from counts, so they stay right even if the
  # offset is missing: page two's *rows* have to be asserted too.
  test "page two contains the second slice of items" do
    25.times { |i| create_item(format("Paged Item %02d", i)) }

    pages = [ 1, 2 ].map do |page|
      get items_url(page: page)
      assert_response :success

      response.body.scan(/Paged Item \d\d/).uniq
    end

    first, second = pages
    assert_equal 20, first.size
    assert_equal 5, second.size
    assert_empty first & second, "page two repeated rows from page one (offset missing)"
  end

  test "per_page widens the page and hides pagination when everything fits" do
    25.times { |i| create_item(format("Wide Page Item %02d", i)) }

    get items_url(per_page: 50)
    assert_response :success
    assert_select "nav[aria-label=Pagination]", count: 0
  end
end
