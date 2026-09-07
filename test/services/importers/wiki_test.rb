# frozen_string_literal: true

require "test_helper"

class Importers::WikiTest < ActiveSupport::TestCase
  def fixture_path
    @fixture_path ||= Rails.root.join("tmp/importers_wiki_test_fixture.json")
  end

  def write_fixture(items)
    FileUtils.mkdir_p(fixture_path.dirname)
    File.write(fixture_path, JSON.generate(items))
  end

  def run_import!
    Importers::Wiki.import!(source: fixture_path)
  end

  def weapon_parsed
    {
      "full_name" => "AS VAL 9x39 special assault rifle",
      "infobox" => {
        "type" => "Assault rifle",
        "slot" => "Primary",
        "trader" => "[[Ref]] LL4",
        "node" => "57c44b372459772d2b39b8ce",
        "ID" => "weapon_tochmash_val_9x39",
        "caliber" => "9x39mm",
        "def_ammo" => "57a0dfb82459774d3078b56c",
        "ammo" => "9x39mm",
        "penetration" => "30",
        "armor" => "5",
        "default_plates" => "2x {{65573fa5655447403702a816}}",
        "default_plates_armor_class" => "5",
        "max_uses" => "100",
        "ergonomics" => "59.5",
        "recoil" => "Vertical: 54<br/>Horizontal: 184",
        "range" => "400",
        "velocity" => "293",
        "effect" => "Generic loot item",
        "image" => "Asval.png",
        "icon" => "Asval icon.png",
        "weight" => "2.5",
        "grid" => "5x2",
        "price" => "12345",
        "fire_modes" => "Single<br/>Full Auto",
        "sightrange" => "420",
        "MOA" => "3.44",
        "rof" => "900"
      },
      "sections" => {
        "mods" => [
          { "slot" => "Muzzle", "items" => [ "57c44dd02459772d2e0ae249", "57838c962459774a1651ec63" ] }
        ],
        "weapon_variants" => [
          { "name" => "AS VAL Kobra", "attachments" => [ "57c44dd02459772d2e0ae249" ] }
        ]
      }
    }
  end

  setup do
    Item.create!(bsg_id: "57c44b372459772d2b39b8ce", slug: "as-val", full_name: "AS VAL (old name)",
                 short_name: "AS VAL", data: { "caliber" => "Caliber9x39" })
    write_fixture({ "57c44b372459772d2b39b8ce" => weapon_parsed })
  end

  teardown do
    FileUtils.rm_f(fixture_path)
  end

  test "wiki full_name wins and wiki_title is set" do
    run_import!

    item = Item.find_by(bsg_id: "57c44b372459772d2b39b8ce")
    assert_equal "AS VAL 9x39 special assault rifle", item.full_name
    assert_equal "AS VAL 9x39 special assault rifle", item.wiki_title
  end

  test "kept infobox params land in data" do
    run_import!

    item = Item.find_by(bsg_id: "57c44b372459772d2b39b8ce")
    assert_equal "9x39mm", item.data["caliber"]
    assert_equal "30", item.data["penetration"]
    assert_equal "5", item.data["armor"]
    assert_equal "100", item.data["max_uses"]
    assert_equal "59.5", item.data["ergonomics"]
    assert_equal "Generic loot item", item.data["effect"]
    assert_equal "Primary", item.data["slot"]
    assert_equal "Assault rifle", item.data["type"]
    assert_equal "weapon_tochmash_val_9x39", item.data["ID"]
    assert_equal "57a0dfb82459774d3078b56c", item.data["def_ammo"]
    assert_equal "57c44b372459772d2b39b8ce", item.data["node"]
  end

  test "pruned infobox params are not stored" do
    run_import!

    item = Item.find_by(bsg_id: "57c44b372459772d2b39b8ce")
    %w[image icon weight grid price fire_modes sightrange MOA rof].each do |key|
      refute item.data.key?(key), "expected #{key} to be pruned"
    end
  end

  test "stores mods and weapon_variants sections" do
    run_import!

    item = Item.find_by(bsg_id: "57c44b372459772d2b39b8ce")
    assert_equal [ { "slot" => "Muzzle", "items" => [ "57c44dd02459772d2e0ae249", "57838c962459774a1651ec63" ] } ],
                 item.data["mods"]
    assert_equal [ { "name" => "AS VAL Kobra", "attachments" => [ "57c44dd02459772d2e0ae249" ] } ],
                 item.data["weapon_variants"]
  end

  test "is idempotent when run twice" do
    run_import!
    run_import!

    item = Item.find_by(bsg_id: "57c44b372459772d2b39b8ce")
    assert_equal "AS VAL 9x39 special assault rifle", item.full_name
    assert_equal 1, item.data["mods"].count
    assert_equal 1, item.data["weapon_variants"].count
  end

  test "skips items not present in the database" do
    write_fixture({ "unknown_hex_000000000000000000000000" => weapon_parsed.merge("full_name" => "Unknown") })

    assert_no_difference "Item.count" do
      run_import!
    end
  end
end
