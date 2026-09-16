require "test_helper"

# The Category filter offers ~170 options, so a menu that long gets a box that
# narrows it. Short menus do not need one and do not get one.
class FilterComponentTest < ViewComponent::TestCase
  def options(count)
    Array.new(count) { |i| { value: "cat-#{i}", label: "Category #{i}", count: i } }
  end

  test "a long menu gets a filter box" do
    render_inline FilterComponent::GroupComponent.new(title: "Category", name: "category", options: options(13))

    assert_selector "[data-filter-options-target=input]", visible: :all
    assert_selector "[data-filter-options-target=option]", count: 13, visible: :all
    assert_selector "[data-filter-options-target=option][data-label='category 12']", visible: :all
  end

  test "a short menu does not" do
    render_inline FilterComponent::GroupComponent.new(title: "Source", name: "source", options: options(4))

    assert_no_selector "[data-filter-options-target=input]", visible: :all
    assert_no_selector "[data-filter-options-target=option]", visible: :all
  end

  test "the menu is a native disclosure so it opens without JavaScript" do
    render_inline FilterComponent::GroupComponent.new(title: "Source", name: "source", options: options(2))

    assert_selector "details.filter-group > summary"
    assert_selector "input[name='filters[source][]']", count: 2, visible: :all
  end
end
