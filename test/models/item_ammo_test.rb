require "test_helper"

class ItemAmmoTest < ActiveSupport::TestCase
  test "is an STI subclass of Item" do
    assert Item::Ammo < Item
  end

  test "persists with type Item::Ammo and reloads as Item::Ammo" do
    item = Item::Ammo.create!(bsg_id: "ammo-#{SecureRandom.hex(4)}", full_name: "5.45x39 PS", short_name: "PS")
    assert_equal "Item::Ammo", item.type
    assert_instance_of Item::Ammo, Item.find(item.id)
  end

  # The wiki chart's scale, level by level: level 4 ("Effective") is where a
  # round starts to penetrate that armor class.
  test "reads the wiki effectiveness levels by armor class" do
    ammo = with_levels({ "1" => 6, "2" => 6, "3" => 5, "4" => 4, "5" => 3, "6" => 0 })

    assert ammo.wiki_effectiveness?
    assert_equal [ 6, 6, 5, 4, 3, 0 ], ammo.armor_class_levels
    assert_equal [ 1, 2, 3, 4 ], ammo.defeated_armor_classes
    assert_equal 4, ammo.defeats_class
    assert ammo.defeats_armor_class?(4)
    refute ammo.defeats_armor_class?(5)
  end

  test "level 4 penetrates an armor class, level 3 does not" do
    assert with_levels({ "1" => 4, "2" => 0, "3" => 0, "4" => 0, "5" => 0, "6" => 0 }).defeats_armor_class?(1)
    refute with_levels({ "1" => 3, "2" => 0, "3" => 0, "4" => 0, "5" => 0, "6" => 0 }).defeats_armor_class?(1)
  end

  test "a round with no chart row falls back to the penetration estimate" do
    ammo = with_levels({}, penetration: 44)

    refute ammo.wiki_effectiveness?
    assert_nil ammo.armor_class_levels
    assert_equal 4, ammo.defeats_class
  end

  test "the chart overrides the penetration estimate" do
    # 24 penetration estimates class 2; the chart rates it 4+ all the way up.
    ammo = with_levels({ "1" => 6, "2" => 6, "3" => 5, "4" => 4, "5" => 4, "6" => 4 }, penetration: 24)

    assert_equal 2, Item.penetration_class(ammo.penetration)
    assert_equal 6, ammo.defeats_class
  end

  private

  def with_levels(levels, penetration: 10)
    Item::Ammo.create!(
      bsg_id: "am-#{SecureRandom.hex(4)}", full_name: "Test round", short_name: "TR",
      armor_class_effectiveness: levels,
      data: { "penetration_power" => penetration, "damage" => 40 }
    )
  end
end
