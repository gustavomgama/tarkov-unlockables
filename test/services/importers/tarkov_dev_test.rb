require "test_helper"

class Importers::TarkovDevTest < ActiveSupport::TestCase
  def fixture_path
    @fixture_path ||= Rails.root.join("tmp/importers_tarkov_dev_test_fixture.json")
  end

  def write_fixture(items)
    FileUtils.mkdir_p(fixture_path.dirname)
    File.write(fixture_path, JSON.generate("data" => { "items" => items }))
  end

  def run_import!
    Importers::TarkovDev.import!(source: fixture_path)
  end

  def weapon_fixture
    {
      "bsg_id" => "weapon_bsg_1",
      "wikiLink" => "https://example.com/wiki/ak-74m",
      "link" => "https://example.com/ak-74m",
      "iconLink" => "https://example.com/ak-74m-icon.png",
      "gridImageLink" => "https://example.com/ak-74m-grid.png",
      "types" => [ "gun", "wearable" ],
      "categories" => [ "5447b5f14bdc2d61278b4567" ],
      "containsItems" => [ { "item" => "ammo_bsg_1", "count" => 1, "attributes" => {} } ],
      "properties" => {
        "propertiesType" => "ItemPropertiesWeapon",
        "caliber" => "Caliber545x39",
        "allowedAmmo" => [ "ammo_bsg_1" ],
        "slots" => [ { "id" => "slot_1", "nameId" => "mod_pistol_grip" } ],
        "presets" => [ "preset_1" ],
        "defaultPreset" => "preset_1",
        "ergonomics" => 45,
        "recoilVertical" => 50,
        "fireRate" => 650
      },
      "buyFromTrader" => [
        {
          "trader" => "5a7c2eca46aef81a7ca2145d",
          "currency" => "RUB",
          "minTraderLevel" => 3,
          "taskUnlock" => nil
        }
      ]
    }
  end

  def ammo_fixture
    {
      "bsg_id" => "ammo_bsg_1",
      "wikiLink" => "https://example.com/wiki/ps",
      "types" => [ "ammo" ],
      "categories" => [ "5485cbdf4bdc2d72e18b4567" ],
      "containsItems" => [],
      "properties" => {
        "propertiesType" => "ItemPropertiesAmmo",
        "caliber" => "Caliber545x39",
        "stackMaxSize" => 120,
        "tracer" => true,
        "tracerColor" => "green",
        "ammoType" => "bullet",
        "damage" => 54,
        "penetrationPower" => 31,
        "ballisticCoeficient" => 1.0,
        "armorDamage" => 25
      },
      "buyFromTrader" => []
    }
  end

  def armor_fixture
    {
      "bsg_id" => "armor_bsg_1",
      "wikiLink" => "https://example.com/wiki/granit",
      "types" => [ "armor" ],
      "categories" => [ "5448c12b4bdc2d02308b456f" ],
      "containsItems" => [],
      "properties" => {
        "propertiesType" => "ItemPropertiesArmor",
        "class" => 6,
        "armorDamage" => 80
      },
      "buyFromTrader" => []
    }
  end

  setup do
    Item.create!(bsg_id: "weapon_bsg_1", slug: "ak-74m", full_name: "AK-74M", short_name: "AK-74M",
                 data: { "caliber" => "Caliber545x39" })
    Item.create!(bsg_id: "ammo_bsg_1", slug: "5.45x39-ps", full_name: "5.45x39mm PS", short_name: "PS",
                 data: { "caliber" => "Caliber545x39" })
    Item.create!(bsg_id: "armor_bsg_1", slug: "granit-sapi", full_name: "Granit SAPI", short_name: "Granit",
                 data: { "class" => 6 })
    write_fixture([ weapon_fixture, ammo_fixture, armor_fixture ].index_by { |i| i["bsg_id"] })
  end

  teardown do
    FileUtils.rm_f(fixture_path)
  end

  test "enriches data with kept weapon properties and drops pruned ones" do
    run_import!

    weapon = Item.find_by(bsg_id: "weapon_bsg_1")
    assert_equal "Caliber545x39", weapon.data["caliber"]
    assert_equal [ "ammo_bsg_1" ], weapon.data["allowedAmmo"]
    assert_equal [ { "id" => "slot_1", "nameId" => "mod_pistol_grip" } ], weapon.data["slots"]
    assert_equal [ "preset_1" ], weapon.data["presets"]
    assert_equal "preset_1", weapon.data["defaultPreset"]
    refute weapon.data.key?("ergonomics")
    refute weapon.data.key?("recoilVertical")
    refute weapon.data.key?("fireRate")
  end

  test "enriches data with kept ammo properties and drops pruned ones" do
    run_import!

    ammo = Item.find_by(bsg_id: "ammo_bsg_1")
    assert_equal "Caliber545x39", ammo.data["caliber"]
    assert_equal 120, ammo.data["stackMaxSize"]
    assert_equal true, ammo.data["tracer"]
    assert_equal "green", ammo.data["tracerColor"]
    assert_equal "bullet", ammo.data["ammoType"]
    assert_equal 54, ammo.data["damage"]
    assert_equal 31, ammo.data["penetrationPower"]
    refute ammo.data.key?("ballisticCoeficient")
    refute ammo.data.key?("armorDamage")
  end

  test "enriches data with kept armor class and drops pruned ones" do
    run_import!

    armor = Item.find_by(bsg_id: "armor_bsg_1")
    assert_equal 6, armor.data["class"]
    refute armor.data.key?("armorDamage")
  end

  test "stores types, categories and containsItems" do
    run_import!

    weapon = Item.find_by(bsg_id: "weapon_bsg_1")
    assert_equal [ "gun", "wearable" ], weapon.data["types"]
    assert_equal [ "5447b5f14bdc2d61278b4567" ], weapon.data["categories"]
    assert_equal [ { "item" => "ammo_bsg_1", "count" => 1, "attributes" => {} } ], weapon.data["containsItems"]
  end

  test "stores wikiLink and link into links and image links into images" do
    run_import!

    weapon = Item.find_by(bsg_id: "weapon_bsg_1")
    assert_includes weapon.links, "https://example.com/wiki/ak-74m"
    assert_includes weapon.links, "https://example.com/ak-74m"
    assert_includes weapon.images, "https://example.com/ak-74m-icon.png"
    assert_includes weapon.images, "https://example.com/ak-74m-grid.png"
  end

  test "creates item_currencies rows from buyFromTrader" do
    run_import!

    weapon = Item.find_by(bsg_id: "weapon_bsg_1")
    currency = weapon.item_currencies.first
    assert_equal "Mechanic", currency.trader
    assert_equal "RUB", currency.currency
    assert_equal 3, currency.min_trader_level
    assert_equal false, currency.task_unlock
  end

  test "is idempotent when run twice" do
    run_import!
    run_import!

    weapon = Item.find_by(bsg_id: "weapon_bsg_1")
    assert_equal 1, weapon.item_currencies.count
    assert_equal 1, weapon.data["presets"].count
    assert_equal 1, weapon.links.count { |l| l == "https://example.com/ak-74m" }
  end

  test "skips items not present in the database" do
    write_fixture(
      "data" => { "items" => {
        "unknown_bsg_1" => weapon_fixture.merge("bsg_id" => "unknown_bsg_1")
      } }
    )

    assert_no_difference "Item.count" do
      run_import!
    end
  end
end
