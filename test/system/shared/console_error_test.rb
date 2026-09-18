require "application_system_test_case"

class ConsoleErrorTest < ApplicationSystemTestCase
  # The palette is loaded from an external stylesheet. Asking for the computed
  # value is the only check that catches a broken declaration block: the
  # response text can contain a token that the browser never applies.
  test "the design tokens actually apply" do
    visit items_path

    assert_equal "rgb(6, 8, 10)", page.evaluate_script("getComputedStyle(document.body).backgroundColor")
    assert_equal "#06080a", page.evaluate_script("getComputedStyle(document.documentElement).getPropertyValue('--bg-dark').trim()")
    assert_equal "false", page.evaluate_script("window.matchMedia('print').matches").to_s
  end

  def test_items_index_has_no_console_errors
    visit items_path
    assert_no_console_errors("Items index should have no console errors")
  end

  def test_tasks_index_has_no_console_errors
    visit tasks_path
    assert_no_console_errors("Tasks index should have no console errors")
  end

  def test_task_chains_has_no_console_errors
    visit chains_tasks_path
    assert_no_console_errors("Task chains should have no console errors")
  end

  def test_root_path_has_no_console_errors
    visit root_path
    assert_no_console_errors("Root path should have no console errors")
  end

  # The empty state renders instead of the grid/table, so the view-toggle
  # controller connects without its targets and threw `Missing target element`
  # on every zero-result search.
  test "the empty search state has no console errors" do
    visit items_path(q: "zzz-no-such-item")

    assert_text "No items match this search."
    assert_no_console_errors("Empty items state should have no console errors")
  end

  test "the empty filter state has no console errors" do
    visit items_path(filters: { category: [ "no-such-category" ] })

    assert_text "No items match this combination of filters."
    assert_no_console_errors("Empty filter state should have no console errors")
  end

  test "the past-the-end page state has no console errors" do
    visit items_path(page: 9999)

    assert_text "That page is past the end of the list."
    assert_no_console_errors("Past-the-end page state should have no console errors")
  end

  test "item show has no console errors" do
    visit item_path(items(:one))

    assert_no_console_errors("Item show should have no console errors")
  end

  test "task show has no console errors" do
    visit task_path(tasks(:one))

    assert_no_console_errors("Task show should have no console errors")
  end

  test "favorites has no console errors" do
    visit favorites_path

    assert_no_console_errors("Favorites should have no console errors")
  end

  # The admin area loads the same Stimulus bundle as the public site; the basic
  # auth header goes through CDP because Chrome rejects credentials in a URL.
  test "admin items index has no console errors" do
    set_basic_auth_header
    visit admin_items_path

    assert_text "Items"
    assert_no_console_errors("Admin items index should have no console errors")
  end

  test "admin unlock form has no console errors" do
    set_basic_auth_header
    visit new_admin_craft_unlock_path

    assert_no_console_errors("Admin unlock form should have no console errors")
  end
end
