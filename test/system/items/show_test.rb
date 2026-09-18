require "application_system_test_case"

# The item page is the site's main reading surface: hero, stats, acquisition
# routes and the unlock panel. These drive it in a browser against the fixtures
# (fixture-only, like every system test — see application_system_test_case.rb).
class ItemShowTest < ApplicationSystemTestCase
  test "the hero shows the name, kind and a link back to the listing" do
    item = items(:one)
    visit item_path(item)

    assert_selector "h1", text: item.full_name
    assert_selector ".crumbs a[href='#{items_path}']", text: "Items"
    assert_selector ".chip--strong", minimum: 1
  end

  test "the where-to-get panel lists every acquisition route on file" do
    item = items(:one)
    visit item_path(item)

    within "section[aria-labelledby='where-head']" do
      # The badges are uppercased by CSS, so match case-insensitively.
      assert_selector ".srcbadge", text: /trader/i
      assert_selector ".srcbadge", text: /barter/i
      assert_selector ".srcbadge", text: /hideout/i
      assert_selector ".srcbadge", text: /quest/i
      assert_text "Prapor"
      assert_text "Workbench"
    end
  end

  test "the unlock panel renders the quest chain for a gated item" do
    visit item_path(items(:one))

    within_section("unlock-head") { assert_unlock_links }
  end

  test "the favorites toggle is present and posts to the favorites route" do
    visit item_path(items(:one))

    assert_selector "form[action^='/favorites']"
    assert_text "Add favorite"
  end

  test "an item with no acquisition data still renders the page" do
    item = items(:two)
    visit item_path(item)

    assert_selector "h1", text: item.full_name
    assert_selector "section[aria-labelledby='where-head']"
  end

  private

  # The page's panels are labelled sections; scoping an assertion to one keeps
  # the same markup from matching elsewhere on the page.
  def within_section(heading_id, &block)
    within("section[aria-labelledby='#{heading_id}']", &block)
  end

  # An unlock panel names the quest(s) that gate the item and links to them.
  def assert_unlock_links
    assert_selector ".srcbadge", minimum: 1
    assert_selector "a[href^='/tasks/']", minimum: 1
  end
end
