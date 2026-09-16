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

  test "Enter still submits the search with JavaScript on" do
    visit items_path

    fill_in "q", with: TERM
    find("#q").send_keys(:enter)

    assert_current_path(/q=test/, ignore_query: false, wait: 5)
    assert_selector "h1", text: "Items"
  end
end
