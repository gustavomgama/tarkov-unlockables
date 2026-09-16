require "system_test_helper"

class ConsoleErrorTest < ActionDispatch::SystemTestCase
  include SystemTestHelper

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
end
