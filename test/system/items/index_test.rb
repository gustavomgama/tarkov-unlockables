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

  def test_remembered_view_survives_a_reload
    visit items_path
    # localStorage is per-origin and outlives a Capybara session, so start from
    # a known state and clear it again or the default-view test can flake.
    page.execute_script("localStorage.removeItem('items_view')")
    visit items_path

    click_on "Table"
    assert_selector "[data-view-toggle-target='table']", visible: true

    visit items_path
    assert_selector "[data-view-toggle-target='table']", visible: true
    assert_selector "[data-view-toggle-target='grid']", visible: false
  ensure
    page.execute_script("localStorage.removeItem('items_view')")
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

  # The table view is a real alternative listing, not a hidden duplicate: it has
  # to carry the same items with their name, short name, type and categories.
  def test_table_view_lists_the_items_with_their_columns
    visit items_path
    click_on "Table"

    within "[data-view-toggle-target='table']" do
      # The headers are uppercased by CSS, so match case-insensitively.
      assert_selector "th", text: /name/i
      assert_selector "th", text: /short name/i
      assert_selector "th", text: /type/i
      assert_selector "th", text: /categories/i
      assert_selector "tbody tr", minimum: 1
      assert_selector "a", text: items(:one).full_name
    end
  end

  # A card links to its item and shows the name; the first card's image is the
  # likely LCP element, so it must not be lazy-loaded.
  def test_a_card_links_to_its_item_and_prioritises_the_first_image
    visit items_path

    within "[data-view-toggle-target='grid']" do
      assert_selector "a.card[href='#{item_path(items(:one))}']"
      assert_selector ".card__name", text: items(:one).full_name
    end

    first_image = first("[data-view-toggle-target='grid'] img", visible: :all)
    if first_image
      assert_equal "high", first_image["fetchpriority"]
    end
  end

  # The page-size control submits the filter form on change.
  def test_changing_the_page_size_reloads_with_that_size
    visit items_path

    select "50", from: "per_page"

    assert_current_path(/per_page=50/, wait: 5)
  end
end
