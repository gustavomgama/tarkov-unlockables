require "system_test_helper"

class ConsoleErrorTest < ActionDispatch::SystemTestCase
  include SystemTestHelper

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
