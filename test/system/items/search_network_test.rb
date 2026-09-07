require "system_test_helper"

class SearchNetworkInspectionTest < ActionDispatch::SystemTestCase
  include SystemTestHelper

  def test_autocomplete_field_exists
    visit items_path
    assert_selector "input[data-search-target=\"input\"]"
  end

  def test_autocomplete_results_container_exists
    visit items_path
    assert_selector "div[data-search-target=\"results\"]", maximum: 1
  end

  def test_autocomplete_loading_indicator_exists
    visit items_path
    assert_selector "div[data-search-target=\"loading\"]", maximum: 1
  end
end
