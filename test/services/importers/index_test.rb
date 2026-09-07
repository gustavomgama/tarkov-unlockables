require "test_helper"

class Importers::IndexTest < ActiveSupport::TestCase
  def fixture_path
    @fixture_path ||= Rails.root.join("tmp/importers_index_test_fixture.json")
  end

  def write_fixture(items)
    FileUtils.mkdir_p(fixture_path.dirname)
    File.write(fixture_path, JSON.generate(items))
  end

  def run_import!
    Importers::Index.import!(source: fixture_path)
  end

  def weapon_fixture
    {
      "bsg_id" => "weapon_bsg_1",
      "slug" => "ak-74m",
      "full_name" => "AK-74M 5.45x39 assault rifle",
      "short_name" => "AK-74M",
      "categories" => [ "gun", "weapon", "assault_rifles" ],
      "links" => [ "https://example.com/ak-74m" ],
      "images" => [ "https://example.com/ak-74m.png" ],
      "properties" => {
        "properties_type" => "ItemPropertiesWeapon",
        "caliber" => "Caliber545x39",
        "allowed_ammo" => [ "ammo_bsg_1" ],
        "default_ammo" => "ammo_bsg_1",
        "presets" => [ "preset_1" ],
        "slots" => [ { "id" => "slot_1", "name_id" => "mod_pistol_grip" } ],
        "unwanted_key" => "should_not_be_kept"
      },
      "obtain_from" => [
        {
          "task_rewards" => [ { "task_id" => "task_1", "task_name" => "Scout", "reward_type" => "finish" } ],
          "hideout" => [ { "station_name" => "Workbench", "station_level" => 2 } ],
          "barter" => [ { "trader_name" => "Jaeger", "trader_level" => "LL2" } ],
          "currency" => [ { "trader_name" => "Peacekeeper", "trader_level" => "3", "currency" => "USD" } ]
        }
      ]
    }
  end

  def ammo_fixture
    {
      "bsg_id" => "ammo_bsg_1",
      "slug" => "5.45x39-ps",
      "full_name" => "5.45x39mm PS gs",
      "short_name" => "PS",
      "categories" => [ "ammo", "ammunition" ],
      "links" => [],
      "images" => [],
      "properties" => {
        "properties_type" => "ItemPropertiesAmmo",
        "caliber" => "Caliber545x39",
        "ammo_type" => "bullet",
        "damage" => 54,
        "penetration_power" => 31
      },
      "obtain_from" => []
    }
  end

  def armor_fixture
    {
      "bsg_id" => "armor_bsg_1",
      "slug" => "granit-sapi",
      "full_name" => "Granit SAPI plate",
      "short_name" => "Granit",
      "categories" => [ "armor", "armor_plates" ],
      "links" => [],
      "images" => [],
      "properties" => {
        "properties_type" => "ItemPropertiesArmor",
        "class" => 6,
        "armor_type" => "Heavy",
        "armor_slots" => [ { "name_id" => "Front_plate" } ],
        "zones" => [ "Armor Zone Plate_Granit_SAPI_chest" ]
      },
      "obtain_from" => []
    }
  end

  def non_dict_property_fixture
    {
      "bsg_id" => "generic_bsg_1",
      "slug" => "some-generic-item",
      "full_name" => "Some generic item",
      "short_name" => "SGI",
      "categories" => [ "general" ],
      "links" => [],
      "images" => [],
      "properties" => "",
      "obtain_from" => []
    }
  end

  def base_weapon_fixture
    {
      "bsg_id" => "base_weapon_bsg_1",
      "slug" => "ak-74m-base",
      "full_name" => "AK-74M (base)",
      "short_name" => "",
      "categories" => [ "gun", "weapon" ],
      "links" => [],
      "images" => [],
      "properties" => { "properties_type" => "ItemPropertiesWeapon", "caliber" => "Caliber545x39" },
      "obtain_from" => []
    }
  end

  setup do
    write_fixture([ weapon_fixture, ammo_fixture, armor_fixture, non_dict_property_fixture, base_weapon_fixture ])
  end

  teardown do
    FileUtils.rm_f(fixture_path)
  end

  test "creates items with correct STI type via Item.type_for" do
    run_import!

    weapon = Item.find_by(bsg_id: "weapon_bsg_1")
    assert_instance_of Item::Weapon, weapon

    ammo = Item.find_by(bsg_id: "ammo_bsg_1")
    assert_instance_of Item::Ammo, ammo

    armor = Item.find_by(bsg_id: "armor_bsg_1")
    assert_instance_of Item::Armor, armor

    generic = Item.find_by(bsg_id: "generic_bsg_1")
    assert_instance_of Item::Generic, generic
  end

  test "stores kept properties in data and drops non-kept keys" do
    run_import!

    weapon = Item.find_by(bsg_id: "weapon_bsg_1")
    assert_equal "Caliber545x39", weapon.data["caliber"]
    assert_equal [ "ammo_bsg_1" ], weapon.data["allowed_ammo"]
    assert_equal "ammo_bsg_1", weapon.data["default_ammo"]
    assert_equal [ "preset_1" ], weapon.data["presets"]
    assert_equal [ { "id" => "slot_1", "name_id" => "mod_pistol_grip" } ], weapon.data["slots"]
    refute weapon.data.key?("unwanted_key")

    ammo = Item.find_by(bsg_id: "ammo_bsg_1")
    assert_equal "Caliber545x39", ammo.data["caliber"]
    assert_equal "bullet", ammo.data["ammo_type"]
    assert_equal 54, ammo.data["damage"]
    assert_equal 31, ammo.data["penetration_power"]

    armor = Item.find_by(bsg_id: "armor_bsg_1")
    assert_equal 6, armor.data["class"]
    assert_equal "Heavy", armor.data["armor_type"]
    assert_equal [ { "name_id" => "Front_plate" } ], armor.data["armor_slots"]
    assert_equal [ "Armor Zone Plate_Granit_SAPI_chest" ], armor.data["zones"]
  end

  test "does not import links or images" do
    run_import!

    weapon = Item.find_by(bsg_id: "weapon_bsg_1")
    assert_empty weapon.links
    assert_empty weapon.images
  end

  test "creates obtain rows from obtain_from" do
    run_import!

    weapon = Item.find_by(bsg_id: "weapon_bsg_1")

    assert_equal [ "Scout" ], weapon.item_task_rewards.pluck(:task_name)

    hideout = weapon.item_hideouts.first
    assert_equal "Workbench", hideout.station
    assert_equal 2, hideout.level

    barter = weapon.item_barters.first
    assert_equal "Jaeger", barter.trader
    assert_equal "2", barter.trader_level

    currency = weapon.item_currencies.first
    assert_equal "Peacekeeper", currency.trader
    assert_equal "USD", currency.currency
    assert_equal 3, currency.min_trader_level
  end

  test "is idempotent when run twice" do
    run_import!
    run_import!

    assert_equal 1, Item.where(bsg_id: "weapon_bsg_1").count
    weapon = Item.find_by(bsg_id: "weapon_bsg_1")
    assert_equal 1, weapon.item_task_rewards.count
    assert_equal 1, weapon.item_hideouts.count
    assert_equal 1, weapon.item_barters.count
    assert_equal 1, weapon.item_currencies.count
  end

  test "imports base weapons (gun category with empty short_name)" do
    run_import!

    base = Item.find_by(bsg_id: "base_weapon_bsg_1")
    assert_instance_of Item::Weapon, base
    assert_equal "", base.short_name
  end

  test "handles non-dict properties gracefully" do
    run_import!

    generic = Item.find_by(bsg_id: "generic_bsg_1")
    assert_instance_of Item::Generic, generic
    assert_equal({}, generic.data)
  end
end
