require "test_helper"

# ItemsHelper is presentation-only, so these call the helpers directly instead
# of rendering a page for each branch.
class ItemsHelperTest < ActionView::TestCase
  include QueryCounting

  test "filter_value_label reads exclude_ref in player language" do
    assert_equal "Ref items", filter_value_label("exclude_ref", "1")
  end

  test "external_link_label uses the known host label" do
    assert_equal "Wiki", external_link_label("https://escapefromtarkov.fandom.com/wiki/Test")
  end

  test "external_link_label falls back to the raw url when unparsable" do
    assert_equal "http://exa mple.com", external_link_label("http://exa mple.com")
  end

  test "card_stats reads a weapon caliber from its name" do
    item = Item::Weapon.new(full_name: "AK-74 5.45x39", data: {})

    assert_equal [ [ "CAL", "5.45x39mm", nil ] ], card_stats(item)
  end

  test "card_stats reads a magazine's round count and caliber" do
    item = Item::Magazine.new(full_name: "AK-74 30-round magazine 5.45x39", data: {})

    assert_equal [ [ "RNDS", "30", nil ], [ "CAL", "5.45x39mm", nil ] ], card_stats(item)
  end

  test "card_stats reports a generic item's part type" do
    item = Item::Generic.new(full_name: "Part", data: { "type" => "Barrel" })

    assert_equal [ [ "PART", "Barrel", nil ] ], card_stats(item)
  end

  test "card_stats is empty for a type with no stats" do
    assert_equal [], card_stats(Item::Key.new(data: {}))
  end

  # --- the empty/edge side of each card-stat branch ---

  test "card_stats is empty for armor with no class" do
    assert_equal [], card_stats(Item::Armor.new(data: {}))
  end

  test "card_stats is empty for a magazine with no round count or caliber" do
    assert_equal [], card_stats(Item::Magazine.new(full_name: "Generic magazine", data: {}))
  end

  test "card_stats is empty for a weapon with no resolvable caliber" do
    assert_equal [], card_stats(Item::Weapon.new(full_name: "Plain rifle", data: {}))
  end

  test "card_stats gives ammo its damage and penetration tone" do
    item = Item::Ammo.new(data: { "damage" => 50, "penetration_power" => 31 })

    assert_equal [ [ "DMG", 50, nil ], [ "PEN", 31, "var(--ac3)" ] ], card_stats(item)
  end

  test "penetration_tone floors at the first armor class" do
    assert_equal "var(--ac1)", penetration_tone(0)
  end

  test "stat_scale keeps a long value at normal size" do
    assert_equal "", stat_scale("Fragmentation Grenade")
    assert_equal "stat--xl", stat_scale("50")
  end

  test "category_chips drops a broad label that is a prefix of a specific one" do
    item = Item::Generic.new(categories: %w[armor_vests helmet armor])

    assert_equal [ "Armor vests" ], category_chips(item)
  end

  # Caliber-shaped categories are already in the item name and `not_functional`
  # is a BSG import flag, so neither belongs in the chips.
  # The six-cell bars are the page's visual armor readout: one filled cell per
  # armor class, capped at six.
  test "the six-cell bars fill one cell per value" do
    assert_equal [ true, true, false, false, false, false ], armor_scale(2)
    assert_equal Array.new(6, true), armor_scale(9)
    assert_equal Array.new(6, false), armor_scale(0)

    assert_equal [ true, true, true, false, false, false ], penetration_scale(35)
    assert_equal Array.new(6, true), penetration_scale(500)
    assert_equal Array.new(6, false), penetration_scale(5)
  end

  test "task_display_name turns a slug into a readable name" do
    assert_equal "Create A Distraction Part 1", task_display_name("create-a-distraction-part-1")
    assert_equal "Debut", task_display_name("Debut")
  end

  # The request-level cache is the reason a page full of bsg_ids costs one
  # query: batching is the point, not the individual lookups.
  test "bsg_items batches every id into one query and remembers misses" do
    a = create_item("Cache A")
    b = create_item("Cache B")

    queries = count_queries do
      assert_equal [ a.id, b.id ], bsg_items([ a.bsg_id, b.bsg_id, "no-such-bsg" ]).map(&:id)
    end

    assert_equal 1, queries, "bsg_items must load all missing ids in one query"
    assert_equal 0, count_queries { bsg_items([ a.bsg_id, "no-such-bsg" ]) },
                 "a repeat lookup (including the negative result) must not query again"
  ensure
    Item.where(id: [ a&.id, b&.id ]).delete_all
  end

  test "category_labels drops internal flags and caliber-shaped categories" do
    item = Item::Generic.new(categories: %w[
      not_functional headphones headphones_pack 5.45x39mm 5.45x39mm_pack .300 .300_box
    ])

    assert_equal [ "Headphones", "Headphones pack" ], category_labels(item)
  end

  test "category_chips keeps a short list untouched" do
    item = Item::Generic.new(categories: %w[headphones helmet])

    assert_equal [ "Headphones", "Helmet" ], category_chips(item)
  end

  test "compatible_ammo keeps only ammo, hardest-hitting first" do
    weapon = Item::Weapon.create!(
      bsg_id: "helper-weapon-#{SecureRandom.hex(4)}",
      full_name: "Helper Weapon",
      data: { "allowed_ammo" => [ "helper-ammo-soft", "helper-ammo-hard", "helper-part" ] }
    )
    Item::Ammo.create!(bsg_id: "helper-ammo-soft", full_name: "Soft", data: { "penetration_power" => 10 })
    Item::Ammo.create!(bsg_id: "helper-ammo-hard", full_name: "Hard", data: { "penetration_power" => 30 })
    Item::Generic.create!(bsg_id: "helper-part", full_name: "Part", data: {})

    assert_equal [ "Hard", "Soft" ], compatible_ammo(weapon).map(&:full_name)
  end
end
