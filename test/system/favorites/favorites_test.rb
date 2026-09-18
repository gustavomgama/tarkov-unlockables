require "application_system_test_case"

# Favorites is the one page with a write path a visitor can reach, and the
# toggle lives on the item page. Fixture-only, like every system test: a row
# created here would leave the test's transaction idle past
# idle_in_transaction_session_timeout and kill the next query.
class FavoritesSystemTest < ApplicationSystemTestCase
  test "the empty state explains how to save an item" do
    visit favorites_path

    assert_selector "h1", text: /favorites/i
    assert_text "Nothing saved yet."
    assert_selector "a[href='#{items_path}']", text: "Browse items"
  end

  test "the item page offers the add-favorite control" do
    visit item_path(items(:one))

    assert_selector "form[action^='/favorites']"
    assert_text "Add favorite"
  end

  test "the favorites page renders no remove control when nothing is saved" do
    visit favorites_path

    assert_no_selector ".card-remove"
    assert_text "Nothing saved yet."
  end

  # The nav renders twice — a desktop bar and a mobile <details> menu — and only
  # one is visible per breakpoint. `click_on` matches both and raises
  # "ambiguous" (or, when the desktop one is hidden, "not visible"), which made
  # this test flake. Click the visible one explicitly.
  test "the favorites nav link is reachable from the item page" do
    visit item_path(items(:one))

    find("nav[aria-label='Primary'] a[href='#{favorites_path}']", visible: :visible).click

    assert_current_path(favorites_path, wait: 5)
    assert_selector "h1", text: /favorites/i
  end
end
