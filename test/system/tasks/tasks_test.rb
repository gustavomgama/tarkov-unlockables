require "system_test_helper"

class TasksIndexTest < ActionDispatch::SystemTestCase
  include SystemTestHelper

  def test_tasks_index_renders_successfully
    visit tasks_path
    assert_selector "h1", text: /tasks/i
  end
end

class TaskSearchSuggestionsTest < ActionDispatch::SystemTestCase
  include SystemTestHelper
  fixtures :all

  test "typing suggests quests" do
    visit tasks_path

    fill_in "q", with: "task one"
    assert_selector "#search-results a", minimum: 1, wait: 5
    assert_selector "#search-results a", text: /Task One/

    find("#q").send_keys(:escape)
    assert_no_selector "#search-results a"
  end
end

class TaskChainsTest < ActionDispatch::SystemTestCase
  include SystemTestHelper

  def test_chains_page_renders_successfully
    visit chains_tasks_path
    assert_selector "h1", text: /chains/i
  end
end
