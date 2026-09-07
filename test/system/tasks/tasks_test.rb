require "system_test_helper"

class TasksIndexTest < ActionDispatch::SystemTestCase
  include SystemTestHelper

  def test_tasks_index_renders_successfully
    visit tasks_path
    assert_selector "h1", text: /tasks/i
  end
end

class TaskChainsTest < ActionDispatch::SystemTestCase
  include SystemTestHelper

  def test_chains_page_renders_successfully
    visit chains_tasks_path
    assert_selector "h1", text: /chains/i
  end

  def test_svg_graph_renders
    visit chains_tasks_path
    assert_selector "svg#task-graph"
  end
end
