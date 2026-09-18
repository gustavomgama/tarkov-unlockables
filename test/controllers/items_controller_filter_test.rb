require "test_helper"

class ItemsControllerFilterTest < ActionDispatch::IntegrationTest
  include ItemsTestHelpers

  test "index filters work without JavaScript" do
    get items_url

    assert_response :success
    # Native <details> opens without a script; the noscript submit is the
    # only way to apply a selection before the change handler runs.
    assert_select "details.filter-group", minimum: 1
    assert_select "noscript button[type=submit]", text: "Apply filters"
    # Dead JS-only affordances must not come back.
    assert_select "button[data-action='filter-group#toggle']", count: 0
    assert_select "div[data-mobile-nav-target='menu']", count: 0
  end

  test "index filters by currency" do
    rub_item = create_item("Ruble Item", short_name: "RI")
    usd_item = create_item("Dollar Item", short_name: "DI")
    rub_item.item_currencies.create!(trader: "Prapor", currency: "RUB", min_trader_level: 1)
    usd_item.item_currencies.create!(trader: "Peacekeeper", currency: "USD", min_trader_level: 2)

    assert_filtered_items({ currency: [ "RUB" ] }, expected: "Ruble Item", excluded: [ "Dollar Item" ])
  ensure
    ItemCurrency.destroy_all
    [ rub_item, usd_item ].each { |i| i&.destroy }
  end

  # The filter joins item_currencies, so an item sold for the same currency by
  # two traders has two matching rows: the join must not duplicate the card.
  test "index lists an item once when several currency rows match" do
    item = create_item("Two Traders Item", short_name: "TT")
    item.item_currencies.create!(trader: "Prapor", currency: "RUB", min_trader_level: 1)
    item.item_currencies.create!(trader: "Therapist", currency: "RUB", min_trader_level: 3)

    get items_url(filters: { currency: [ "RUB" ] })

    assert_response :success
    assert_select "td a", text: "Two Traders Item", count: 1
  ensure
    ItemCurrency.destroy_all
    item&.destroy
  end

  test "index survives malformed filter params" do
    # params[:filters] comes from the query string: it can be a String or an
    # Array rather than a nested hash, and each of these 500'd at some point.
    [
      { filters: "string" },
      { filters: [ "x" ] },
      { filters: { currency: "string" } },
      { filters: { nonsense: [ "x" ] } },
      { filters: { armor_class: [ "<script>" ] } }
    ].each do |params|
      get items_url(params)
      assert_response :success, "expected 200 for #{params.inspect}"
    end
  end

  test "active filter pills read in player language, not raw keys" do
    item = create_item("Pill Test Item", short_name: "PTI")
    item.item_currencies.create!(trader: "Prapor", currency: "RUB", min_trader_level: 1)

    get items_url(filters: { caliber: [ "Caliber556x45NATO" ], armor_class: [ "6" ], category: [ "noFlea" ] })

    assert_response :success
    assert_select ".chip", text: /Caliber: 5\.56x45mm NATO/
    assert_select ".chip", text: /Armor class: Class 6/
    assert_select ".chip", text: /Category: Not on flea market/
    # Raw keys stay in the form values (they are what the query needs) but
    # must never be what the user reads.
    assert_select ".chip", text: /Caliber556x45NATO/, count: 0
    assert_select ".chip", text: /noFlea/, count: 0
  ensure
    ItemCurrency.destroy_all
    item&.destroy
  end

  test "index exclude_ref filter hides items sold by Ref" do
    ref_item = create_item("Ref Item", short_name: "RF")
    other_item = create_item("Other Item", short_name: "OI")
    ref_item.item_currencies.create!(trader: "Ref", currency: "EUR", min_trader_level: 1)
    other_item.item_currencies.create!(trader: "Prapor", currency: "RUB", min_trader_level: 1)

    assert_filtered_items({ exclude_ref: [ "1" ] }, expected: "Other Item", excluded: [ "Ref Item" ])

    # Without the filter both show
    get items_url
    assert_select "td a", text: "Ref Item"
  ensure
    ItemCurrency.destroy_all
    [ ref_item, other_item ].each { |i| i&.destroy }
  end

  test "index filters by category" do
    head_item = create_item("Headphones Pro", short_name: "HP", categories: [ "headphones" ])
    gun_item = create_item("AK-74", short_name: "AK", categories: [ "assault_rifles" ])

    assert_filtered_items({ category: [ "headphones" ] }, expected: "Headphones Pro", excluded: [ "AK-74" ])
  ensure
    [ head_item, gun_item ].each { |i| i&.destroy }
  end

  # A base category also matches its pack/box/bundle variants: ticking "ammo"
  # must not hide the ammo boxes (the filter groups the family together).
  test "index filters by category including its pack and box variants" do
    base = create_item("Loose Rounds", short_name: "LR", categories: [ "testcat" ])
    pack = create_item("Rounds Pack", short_name: "RP", categories: [ "testcat_pack" ])
    box = create_item("Rounds Box", short_name: "RB", categories: [ "testcat_box" ])
    unrelated = create_item("Elsewhere", short_name: "EW", categories: [ "othercat" ])

    assert_filtered_items({ category: [ "testcat" ] },
                          expected: [ "Loose Rounds", "Rounds Pack", "Rounds Box" ],
                          excluded: [ "Elsewhere" ])
  ensure
    [ base, pack, box, unrelated ].each { |i| i&.destroy }
  end

  test "index filters by caliber" do
    ammo545 = create_item("5.45x39mm BP", klass: Item::Ammo, short_name: "BP", data: { "caliber" => "5.45x39mm", "damage" => 40 })
    ammo762 = create_item("7.62x39mm PS", klass: Item::Ammo, short_name: "PS", data: { "caliber" => "7.62x39mm", "damage" => 50 })

    assert_filtered_items({ caliber: [ "5.45x39mm" ] }, expected: "5.45x39mm BP", excluded: [ "7.62x39mm PS" ])
  ensure
    [ ammo545, ammo762 ].each { |i| i&.destroy }
  end

  test "index filters by armor class" do
    armor4 = create_item("Trooper Class 4", klass: Item::Armor, short_name: "T4", data: { "class" => "4" })
    armor6 = create_item("Zabralo Class 6", klass: Item::Armor, short_name: "Z6", data: { "class" => "6" })

    assert_filtered_items({ armor_class: [ "4" ] }, expected: "Trooper Class 4", excluded: [ "Zabralo Class 6" ])
  ensure
    [ armor4, armor6 ].each { |i| i&.destroy }
  end

  # An ammo box carries its caliber as a category, not as data, so the caliber
  # filter unions both or the boxes are hidden.
  test "index filters by caliber including its pack and box categories" do
    ammo = create_item("5.45x39mm BP", klass: Item::Ammo, short_name: "BP", data: { "caliber" => "5.45x39mm" })
    box = create_item("5.45x39mm Box", short_name: "BX", categories: [ "5.45x39mm_box" ])
    other = create_item("9x19mm PS", klass: Item::Ammo, short_name: "PS", data: { "caliber" => "9x19mm" })

    assert_filtered_items({ caliber: [ "5.45x39mm" ] },
                          expected: [ "5.45x39mm BP", "5.45x39mm Box" ],
                          excluded: [ "9x19mm PS" ])
  ensure
    [ ammo, box, other ].each { |i| i&.destroy }
  end

  test "index filters by several armor classes at once" do
    light = create_item("Trooper Class 4", klass: Item::Armor, short_name: "T4", data: { "class" => "4" })
    heavy = create_item("Slick Class 5", klass: Item::Armor, short_name: "S5", data: { "class" => "5" })
    top = create_item("Zabralo Class 6", klass: Item::Armor, short_name: "Z6", data: { "class" => "6" })

    assert_filtered_items({ armor_class: %w[4 5] },
                          expected: [ "Trooper Class 4", "Slick Class 5" ],
                          excluded: [ "Zabralo Class 6" ])
  ensure
    [ light, heavy, top ].each { |i| i&.destroy }
  end

  test "index filters by task_required" do
    gated, task = create_task_gated_item("Task Gated Item")
    free = create_item("Free Item")

    assert_filtered_items({ task_required: [ "1" ] }, expected: "Task Gated Item", excluded: [ "Free Item" ])
  ensure
    destroy_unlock_fixtures(gated, [ task ])
    free&.destroy
  end

  test "index handles multiple filters combined" do
    rub_head = create_item("Rub Head", short_name: "RH", categories: [ "headphones" ])
    rub_gun = create_item("Rub Gun", short_name: "RG", categories: [ "assault_rifles" ])
    usd_head = create_item("USD Head", short_name: "UH", categories: [ "headphones" ])
    rub_head.item_currencies.create!(trader: "Prapor", currency: "RUB", min_trader_level: 1)
    rub_gun.item_currencies.create!(trader: "Prapor", currency: "RUB", min_trader_level: 1)
    usd_head.item_currencies.create!(trader: "Peacekeeper", currency: "USD", min_trader_level: 2)

    assert_filtered_items({ currency: [ "RUB" ], category: [ "headphones" ] }, expected: "Rub Head", excluded: [ "Rub Gun", "USD Head" ])
  ensure
    ItemCurrency.destroy_all
    [ rub_head, rub_gun, usd_head ].each { |i| i&.destroy }
  end

  test "index with empty filter values does not crash" do
    get items_url(filters: { currency: [ "" ], caliber: [ "" ], category: [ "" ] })
    assert_response :success
  end

  test "index filters by source task_gated" do
    gated, task = create_task_gated_item("Gated Source", task_name: "Source Task")
    free = create_item("Free Source")

    assert_filtered_items({ source: [ "task_gated" ] }, expected: "Gated Source", excluded: [ "Free Source" ])
  ensure
    destroy_unlock_fixtures(gated, [ task ])
    free&.destroy
  end

  test "index filters by source trader" do
    trader_item = create_item("Trader Item", short_name: "TI")
    other_item = create_item("Other Item", short_name: "OI")
    trader_item.item_currencies.create!(trader: "Prapor", currency: "RUB", min_trader_level: 1)

    assert_filtered_items({ source: [ "trader" ] }, expected: "Trader Item", excluded: [ "Other Item" ])
  ensure
    ItemCurrency.destroy_all
    [ trader_item, other_item ].each { |i| i&.destroy }
  end

  test "index filters with source and category combined" do
    item_a = create_item("Trader Headphone", short_name: "TH", categories: [ "headphones" ])
    item_b = create_item("Trader Gun", short_name: "TG", categories: [ "assault_rifles" ])
    item_c = create_item("No Trader Headphone", short_name: "NH", categories: [ "headphones" ])
    item_a.item_currencies.create!(trader: "Prapor", currency: "RUB", min_trader_level: 1)
    item_b.item_currencies.create!(trader: "Prapor", currency: "RUB", min_trader_level: 1)

    assert_filtered_items({ source: [ "trader" ], category: [ "headphones" ] }, expected: "Trader Headphone", excluded: [ "Trader Gun", "No Trader Headphone" ])
  ensure
    ItemCurrency.destroy_all
    [ item_a, item_b, item_c ].each { |i| i&.destroy }
  end

  test "index with all filter options checked returns all items" do
    total_before = Item.count

    all_currencies = ItemCurrency.distinct.pluck(:currency).compact
    all_armor_classes = Item.distinct.pluck(Arel.sql("data->>'class'")).compact
    all_calibers = Item.distinct.pluck(Arel.sql("data->>'caliber'")).compact

    # Build category base values (merged pack/box/bundle)
    raw_cats = Item.pluck(:categories).flatten.uniq
    all_category_bases = raw_cats.map { |c| c.sub(/_(pack|box|bundle)\z/, "") }.uniq

    all_sources = %w[barter craft trader hideout task_gated]

    get items_url(filters: {
      currency: all_currencies,
      category: all_category_bases,
      armor_class: all_armor_classes,
      caliber: all_calibers,
      source: all_sources
    })
    assert_response :success
    # All items should be present — every checked group is skipped since all values selected
    assert_select "table tbody tr", count: total_before
  end

  # The grouped variant counts are internal to the filter options. Two of its
  # paths never arise from a request while fixtures are loaded (no categories at
  # all, and a category the variant list does not cover), so call it directly.
  test "variant_counts_for handles no variants and categories outside the list" do
    controller = ItemsController.new
    assert_equal({}, controller.send(:variant_counts_for, []))

    item = create_item("Counted", categories: [ "general", "uncounted_cat" ])
    counts = controller.send(:variant_counts_for, [ "general" ])

    assert_operator counts["general"], :>=, 1
    refute counts.key?("uncounted_cat")
  ensure
    item&.destroy
  end

  # The "craft" value has always filtered quest rewards (item_task_rewards); the
  # option said "Craft" while the item page calls the same data "Quest". The
  # value is unchanged so existing filtered URLs keep working.
  test "the source filter names the quest-reward option and still accepts the craft value" do
    get items_url

    assert_response :success
    assert_select "span.filter-group__label", text: "Quest reward"

    get items_url(filters: { source: [ "craft" ] })

    assert_response :success
    assert_select "table tbody tr", minimum: 1
  end
end
