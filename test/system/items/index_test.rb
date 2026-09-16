require "application_system_test_case"

class ItemsIndexTest < ApplicationSystemTestCase
  def test_items_index_renders_successfully
    visit items_path
    assert_selector "h1", text: /items/i
  end

  def test_items_display_in_grid_view_by_default
    visit items_path
    assert_selector "[data-view-toggle-target='grid']", visible: true
  end

  def test_search_input_exists
    visit items_path
    # Mobile and desktop each render a q input; only one is visible per breakpoint.
    assert_selector "input[name='q']", minimum: 1, visible: :all
  end

  def test_view_toggle_switches_between_grid_and_table
    visit items_path

    click_on "Table"
    assert_selector "[data-view-toggle-target='table']", visible: true
    assert_selector "[data-view-toggle-target='grid']", visible: false

    click_on "Grid"
    assert_selector "[data-view-toggle-target='grid']", visible: true
    assert_selector "[data-view-toggle-target='table']", visible: false
  end
end
