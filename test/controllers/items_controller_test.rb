require "test_helper"

class ItemsControllerTest < ActionDispatch::IntegrationTest
  include ItemsTestHelpers

  def setup
    @item = create_item("Test Item", short_name: "TI")
  end

  def teardown
    @item.destroy if @item
  end

  # The filter option with this value, asserted to display the given count.
  def assert_option_count(value, count)
    option = css_select("label.filter-group__option").find { |label| label.at_css("input")&.[]("value") == value }

    assert option, "expected a filter option with value #{value.inspect}"
    assert_equal count, option.at_css(".filter-group__hint")&.text&.strip,
                 "option #{value.inspect} should show its match count"
  end

  test "should get index" do
    get items_url
    assert_response :success
  end

  # Each option shows how many items it would return, so a tick's cost is
  # visible before applying it.
  test "filter options show how many items they would return" do
    caliber = "TestCountCal"
    3.times { |i| create_item("Count Ammo #{i}", klass: Item::Ammo, data: { "caliber" => caliber }) }
    2.times { |i| create_item("Count Cat #{i}", categories: [ "testcountcat" ]) }

    # A pack carries its caliber as a category, not as data, so the caliber
    # option's count has to union both sources. The map is keyed by the *display*
    # form, so this needs one (".50 AE" → ".50_ae").
    create_item("Union Ammo", klass: Item::Ammo, data: { "caliber" => ".50 AE" })
    create_item("Union Pack", categories: [ ".50_ae" ])

    get items_url

    assert_response :success
    assert_option_count(caliber, "3")
    assert_option_count("testcountcat", "2")
    assert_option_count(".50 AE", "2")
  ensure
    Item.where(full_name: [ "Count Ammo 0", "Count Ammo 1", "Count Ammo 2", "Count Cat 0", "Count Cat 1",
                            "Union Ammo", "Union Pack" ]).delete_all
  end

  # The empty state names its cause and offers the action that undoes it; the
  # three variants live in one partial and nothing asserted them (axe visits the
  # empty pages but never reads the message).
  test "index names why the result list is empty" do
    # More than one page, so the :page variant is reachable.
    20.times { |i| create_item(format("Empty State Item %02d", i)) }

    get items_url(q: "no-such-item-anywhere")
    assert_select "p", text: /No items match this search/
    assert_select "a", text: "Show all items"

    # Two calibers and two armor classes so both groups are partially selectable
    # (a fully-selected group is a no-op by design), and an intersection that
    # cannot match: an ammo round with an armor class it does not have.
    create_item("Filter Ammo A", klass: Item::Ammo, data: { "caliber" => "FilterCalA", "class" => "4" })
    create_item("Filter Ammo B", klass: Item::Ammo, data: { "caliber" => "FilterCalB" })
    create_item("Filter Armor", klass: Item::Armor, data: { "class" => "6" })

    get items_url(filters: { caliber: [ "FilterCalA" ], armor_class: [ "6" ] })
    assert_select "p", text: /No items match this combination of filters/
    assert_select "a", text: "Clear filters"

    get items_url(page: 999)
    assert_select "p", text: /That page is past the end of the list/
    assert_select "a", text: "Back to page 1"
  ensure
    Item.where("full_name LIKE 'Empty State Item%' OR full_name LIKE 'Filter %'").delete_all
  end

  # The listing's chrome: the clear-all link, the removable filter pills and the
  # per-card readout. None of it was asserted (the filter tests assert the rows).
  test "index shows the clear-all link and the active filter pills" do
    create_item("Pill Item", klass: Item::Ammo, data: { "caliber" => "PillCal" })

    get items_url(filters: { caliber: [ "PillCal" ] })

    assert_response :success
    assert_select "a", text: "Clear all"
    assert_select ".chip--strong", text: /Caliber: PillCal/
  ensure
    Item.where(full_name: "Pill Item").delete_all
  end

  test "index cards show their stats and category chips" do
    create_item("Card Ammo", klass: Item::Ammo, short_name: "CA",
                categories: [ "testcardcat" ],
                data: { "caliber" => "CardCal", "damage" => 42, "penetration_power" => 30 })

    get items_url

    assert_response :success
    assert_select ".card" do
      assert_select ".card__name", text: "Card Ammo"
      assert_select "span", text: "DMG"
      assert_select "span", text: "42"
      assert_select ".chip", text: "Testcardcat"
    end
  ensure
    Item.where(full_name: "Card Ammo").delete_all
  end

  test "site menu is a native disclosure" do
    get items_url

    assert_response :success
    assert_select "details.site-menu summary[aria-label=Menu]"
    assert_select "details.site-menu a[href=?]", items_path
    assert_select "details.site-menu a[href=?]", tasks_path
    assert_select "details.site-menu a[href=?]", favorites_path
  end

  test "the layout states when the reference data last changed" do
    get items_url

    assert_response :success
    assert_select "time[datetime]", minimum: 1
    assert_match(/data updated/, response.body)
  end

  test "search suggests matching items as rows" do
    item = create_item("Alpha Autocomplete", short_name: "AA", categories: [ "testautocat" ])

    get search_items_url(q: "alpha autocomplete")

    assert_response :success
    assert_select "a[href=?]", item_path(item) do
      assert_select "span", text: "Alpha Autocomplete"
      assert_select "span", text: "AA"
      assert_select ".chip", text: "Testautocat"
    end
  ensure
    item&.destroy
  end

  test "search ignores a query shorter than the minimum" do
    get search_items_url(q: "a")
    assert_response :no_content

    get search_items_url
    assert_response :no_content
  end

  test "search returns no content when nothing matches" do
    get search_items_url(q: "zzzzzzzzzzzz")
    assert_response :no_content
  end

  test "search caps how many suggestions it returns" do
    created = Array.new(ApplicationController::AUTOCOMPLETE_LIMIT + 4) do |i|
      create_item("Cap Suggestion #{i}", short_name: "CS#{i}")
    end

    get search_items_url(q: "cap suggestion")

    assert_response :success
    assert_select "a", maximum: ApplicationController::AUTOCOMPLETE_LIMIT
  ensure
    Item.where(id: created&.map(&:id)).delete_all
  end

  test "index search by full_name returns matching items" do
    alpha = create_item("Alpha Scope", short_name: "AS")
    beta = create_item("Beta Grip", short_name: "BG")

    assert_index_search("Alpha", expected: "Alpha Scope", excluded: [ "Beta Grip" ])
  ensure
    [ alpha, beta ].each { |i| i&.destroy }
  end

  test "index search by short_name returns matching items" do
    alpha = create_item("Alpha Scope 2", short_name: "ALF")
    beta = create_item("Beta Grip 2", short_name: "BTA")

    assert_index_search("ALF", expected: "ALF", excluded: [ "BTA" ], selector: "td")
  ensure
    [ alpha, beta ].each { |i| i&.destroy }
  end

  test "index caliber filter also matches ammo packs by their category" do
    loose = create_item("5.45x39mm BT", klass: Item::Ammo, short_name: "BT", data: { "caliber" => "5.45x39mm" })
    other = create_item("7.62x39mm PS", klass: Item::Ammo, short_name: "PS", data: { "caliber" => "7.62x39mm" })
    pack = create_item("5.45x39mm BT ammo pack", short_name: "BTP", categories: [ "ammobox", "5.45x39mm_pack" ])

    assert_filtered_items({ caliber: [ "5.45x39mm" ] }, expected: [ "5.45x39mm BT", "5.45x39mm BT ammo pack" ], excluded: [ "7.62x39mm PS" ])
  ensure
    [ loose, other, pack ].each { |i| i&.destroy }
  end
end
