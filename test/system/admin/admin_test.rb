require "application_system_test_case"

# The admin panel is a real browser surface too: it loads the same Stimulus
# bundle, and its forms are the only place a person edits data. These drive it
# through Chrome with the basic-auth header set over CDP.
#
# Fixture-only, like every other system test: the app runs in a second thread,
# and a row created here leaves the test's transaction idle past
# `idle_in_transaction_session_timeout` (10s), which kills the next query. So
# these assert rendering and navigation, not writes.
class AdminSystemTest < ApplicationSystemTestCase
  def setup
    set_basic_auth_header
  end

  test "admin items index renders with its table and search" do
    visit admin_items_path

    assert_selector "h1", text: /items/i
    assert_selector "table"
    assert_selector "input[name='q']"
    assert_no_console_errors("Admin items index should have no console errors")
  end

  test "admin item form renders every field with the stored values" do
    item = items(:one)

    visit edit_admin_item_path(item)

    assert_selector "input[name='item[full_name]'][value='#{item.full_name}']"
    assert_selector "textarea[name='item[data]']"
    assert_selector "input[name='item[categories]']"
    assert_no_console_errors("Admin item form should have no console errors")
  end

  test "admin task form renders with the stored values" do
    task = tasks(:one)

    visit edit_admin_task_path(task)

    assert_selector "input[name='task[full_name]'][value='#{task.full_name}']"
    assert_selector "input[name='task[name]'][value='#{task.name}']"
  end

  test "admin unlock form renders its item picker" do
    visit new_admin_craft_unlock_path

    assert_selector "select[name='craft_unlock[item_id]']"
    assert_no_console_errors("Admin unlock form should have no console errors")
  end

  test "admin dashboard lists the models with manage links" do
    visit admin_root_path

    assert_selector "h1", text: /dashboard/i
    assert_selector "a", text: "Manage", minimum: 1
  end

  test "the admin nav reaches every resource index" do
    visit admin_items_path

    [ "Tasks", "Requirements", "Rewards", "Barter Unlocks", "Craft Unlocks", "Offer Unlocks" ].each do |label|
      click_on label
      assert_selector "h1", text: /#{label}/i
    end
  end
end
