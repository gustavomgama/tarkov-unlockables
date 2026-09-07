require "system_test_helper"

class ItemsIndexTest < ActionDispatch::SystemTestCase
  include SystemTestHelper

  def test_items_index_renders_successfully
    visit items_path
    assert_selector "h1", text: /items/i
  end

  def test_items_display_in_grid_view_by_default
    visit items_path
    assert_selector ".grid", minimum: 1
  end

  def test_search_input_exists
    visit items_path
    assert_selector "input[data-search-target=\"input\"]"
  end

  def test_theme_toggle_exists
    visit items_path
    assert_selector "button[data-action=\"theme#toggle\"]"
  end
end
