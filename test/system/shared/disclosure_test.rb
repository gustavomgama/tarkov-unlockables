require "application_system_test_case"

# The mobile site menu and the index filter groups are native <details>
# elements, so they open without JavaScript and report their own state. This
# covers the behaviour the vanilla <details> element does not give us for
# free: Escape closes and returns focus.
class DisclosureTest < ApplicationSystemTestCase
  # The fixture set only populates some groups, so open the first one that
  # actually offers options. Returns the opened group.
  def open_filter_group_with_options
    group = all(".filter-group").find { |g| g.has_css?("input[type=checkbox]", visible: :all) }
    assert group, "no filter group with options on the index"

    group.find("summary").click
    group
  end

  test "site menu opens on a phone viewport and closes with Escape" do
    visit items_path
    use_viewport(390, 800)

    assert_no_selector ".site-menu[open]"
    find(".site-menu > summary").click
    assert_selector ".site-menu[open]"
    assert_selector ".site-menu__panel a", count: 3

    find(".site-menu > summary").send_keys(:escape)
    assert_no_selector ".site-menu[open]"
  end

  test "site menu is hidden at desktop width" do
    visit items_path
    use_viewport(1280, 900)

    assert_no_selector ".site-menu", visible: true
  end

  test "filter group opens, applies the filter and closes with Escape" do
    visit items_path

    assert_no_selector ".filter-group[open]"

    open_filter_group_with_options
    assert_selector ".filter-group[open] input[type=checkbox]", minimum: 1

    within(".filter-group[open]") { first("input[type=checkbox]").check }

    # Applied: the group re-renders counting the selection, and the active
    # filter pill names it.
    assert_selector ".filter-group__count", text: "1"
    assert_selector ".chip", text: /:/

    # The submission replaced the body, so every group is closed again.
    first(".filter-group > summary").click
    assert_selector ".filter-group[open]"
    find(".filter-group[open] > summary").send_keys(:escape)
    assert_no_selector ".filter-group[open]"
  end

  test "clicking outside a filter group closes it" do
    visit items_path

    open_filter_group_with_options
    assert_selector ".filter-group[open]"

    # A click anywhere outside the group closes it.
    find("h1", text: "Items").click
    assert_no_selector ".filter-group[open]"
  end

  test "view toggle reports which view is active" do
    visit items_path

    # The markup ships aria-pressed="false" on both buttons and the Stimulus
    # controller sets the active one on connect. Reading the attribute straight
    # after visit races that connect, so wait through the retrying matcher.
    assert_selector "[data-view='grid'][aria-pressed='true']"
    assert_selector "[data-view='table'][aria-pressed='false']"

    click_on "Table"
    assert_selector "[data-view-toggle-target='table']", visible: true
    assert_selector "[data-view='table'][aria-pressed='true']"
    assert_selector "[data-view='grid'][aria-pressed='false']"
  end
end
