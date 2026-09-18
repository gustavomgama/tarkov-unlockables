require "application_system_test_case"

# The search field suggests items as you type. Without JavaScript it is still
# a plain form input, so both paths have to keep working.
#
# Fixtures only: a system test must not create or delete rows from the test
# process. The app runs in a second thread, and a pool connection left idle in
# a transaction for more than idle_in_transaction_session_timeout (10s, see
# config/database.yml) is killed by Postgres, which fails every later query in
# the run.
class SearchSuggestionsTest < ApplicationSystemTestCase
  TERM = "test item".freeze

  # Types the shared term on the index and waits for the suggestions to land.
  def suggest_items(count: nil)
    visit items_path
    fill_in "q", with: TERM
    if count
      assert_selector "#search-results a", count: count, wait: 5
    else
      assert_selector "#search-results a", minimum: 1, wait: 5
    end
  end

  test "typing suggests items and Escape dismisses them" do
    suggest_items

    assert_selector "#search-results a", text: /Test Item One/

    find_by_id("q").send_keys(:escape)
    assert_no_selector "#search-results a"
  end

  # `<input type="search">` clears itself on Escape, which hides the suggestions
  # through the query path — so the native route cannot prove the controller's
  # own Escape handling works. A synthetic keydown (which does not clear the
  # field) exercises it: the list must go and the text must stay.
  test "Escape is handled by the controller, not only by the search input" do
    suggest_items

    page.execute_script(<<~JS)
      document.getElementById("q").dispatchEvent(
        new KeyboardEvent("keydown", { key: "Escape", bubbles: true, cancelable: true })
      )
    JS

    assert_no_selector "#search-results a"
    assert_equal TERM, find_by_id("q").value, "the controller must dismiss the list without clearing the field"
  end

  test "a suggestion links to the item" do
    suggest_items

    find("#search-results a", text: /Test Item One/).click
    assert_selector "h1", text: "Test Item One"
  end

  test "clicking outside hides the suggestions" do
    suggest_items

    # Document-level listener: a click anywhere outside the search wrapper.
    find("h1", text: "Items").click
    assert_no_selector "#search-results a"
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
    assert_equal "m85/", find_by_id("q").value
  end

  test "arrow keys move through the suggestions" do
    suggest_items(count: 2)

    focused_name = -> { page.evaluate_script("document.activeElement.querySelector('.font-bold')?.textContent") }
    # The action builder sends to whatever is focused; Element#send_keys would
    # refocus the input and reset the controller's cursor each time.
    arrow = ->(key) { page.driver.browser.action.send_keys(key).perform }

    arrow.call(:arrow_down)
    assert_equal "Test Item One", focused_name.call

    arrow.call(:arrow_down)
    assert_equal "Test Item Two", focused_name.call

    arrow.call(:arrow_up)
    assert_equal "Test Item One", focused_name.call

    # ArrowUp at the top of the list wraps to the last entry.
    arrow.call(:arrow_up)
    assert_equal "Test Item Two", focused_name.call
  end

  test "ArrowUp with nothing focused starts at the last suggestion" do
    suggest_items(count: 2)

    # Nothing in the list is focused, so the cursor sits at -1; ArrowUp has to
    # land on the last entry rather than the one before it.
    page.driver.browser.action.send_keys(:arrow_up).perform

    focused_name = page.evaluate_script("document.activeElement.querySelector('.font-bold')?.textContent")
    assert_equal "Test Item Two", focused_name
  end

  test "Enter still submits the search with JavaScript on" do
    visit items_path

    fill_in "q", with: TERM
    find_by_id("q").send_keys(:enter)

    assert_current_path(/q=test/, ignore_query: false, wait: 5)
    assert_selector "h1", text: "Items"
  end
end
