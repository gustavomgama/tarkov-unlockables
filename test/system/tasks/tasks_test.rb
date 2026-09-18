require "application_system_test_case"

class TasksIndexTest < ApplicationSystemTestCase
  def test_tasks_index_renders_successfully
    visit tasks_path
    assert_selector "h1", text: /tasks/i
  end
end

class TaskSearchSuggestionsTest < ApplicationSystemTestCase
  test "typing suggests quests" do
    visit tasks_path

    fill_in "q", with: "task one"
    assert_selector "#search-results a", minimum: 1, wait: 5
    assert_selector "#search-results a", text: /Task One/

    find_by_id("q").send_keys(:escape)
    assert_no_selector "#search-results a"
  end
end

class TaskChainsTest < ApplicationSystemTestCase
  def test_chains_page_renders_successfully
    visit chains_tasks_path
    assert_selector "h1", text: /chains/i
  end
end
