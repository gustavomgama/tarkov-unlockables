require "system_test_helper"

# The search field suggests items as you type. Without JavaScript it is still
# a plain form input, so both paths have to keep working.
#
# Fixtures only: a system test must not create or delete rows from the test
# process. The app runs in a second thread, and a pool connection left idle in
# a transaction for more than idle_in_transaction_session_timeout (10s, see
# config/database.yml) is killed by Postgres, which fails every later query in
# the run.
class SearchSuggestionsTest < ActionDispatch::SystemTestCase
  include SystemTestHelper

  fixtures :all

  TERM = "test item".freeze

  test "typing suggests items and Escape dismisses them" do
    visit items_path

    fill_in "q", with: TERM
    assert_selector "#search-results a", minimum: 1, wait: 5
    assert_selector "#search-results a", text: /Test Item One/

    find("#q").send_keys(:escape)
    assert_no_selector "#search-results a"
  end

  test "a suggestion links to the item" do
    visit items_path

    fill_in "q", with: TERM
    assert_selector "#search-results a", minimum: 1, wait: 5

    find("#search-results a", text: /Test Item One/).click
    assert_selector "h1", text: "Test Item One"
  end

  test "a query with no matches says so instead of showing nothing" do
    visit items_path

    fill_in "q", with: "zzqqxxnothing"
    assert_selector "#search-results", text: /No matches for/, wait: 5
  end

  # Element#send_keys does not reach a document-level listener, so drive the
  # real key event with the action builder.
  test "slash focuses the search field" do
    visit items_path

    page.driver.browser.action.send_keys("/").perform
    assert_equal "q", page.evaluate_script("document.activeElement.id")
  end

  test "slash is typed, not treated as a shortcut, while already typing" do
    visit items_path

    fill_in "q", with: "m85"
    page.driver.browser.action.send_keys("/").perform
    assert_equal "m85/", find("#q").value
  end

  test "Enter still submits the search with JavaScript on" do
    visit items_path

    fill_in "q", with: TERM
    find("#q").send_keys(:enter)

    assert_current_path(/q=test/, ignore_query: false, wait: 5)
    assert_selector "h1", text: "Items"
  end
end
