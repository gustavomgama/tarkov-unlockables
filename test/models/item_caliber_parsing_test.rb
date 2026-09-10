# frozen_string_literal: true

require "test_helper"

class ItemCaliberParsingTest < ActiveSupport::TestCase
  test "parses caliber from preset name without dot prefix" do
    assert_equal ".300 Blackout", Item.parse_caliber_from_name("Aklys Defense Velociraptor 300 Blackout Assault Rifle Default")
  end

  test "parses caliber with different case (9X19 vs 9x19)" do
    assert_equal "9x19mm Parabellum", Item.parse_caliber_from_name("Tdi Kriss Vector Gen2 9X19 Submachine Gun Default")
  end

  test "parses caliber from 762X51 without dot" do
    assert_equal "7.62x51mm NATO", Item.parse_caliber_from_name("Kalashnikov Ak 308 762X51 Assault Rifle Vudu 1 6")
  end

  test "parses caliber from 45 ACP without dot" do
    assert_equal ".45 ACP", Item.parse_caliber_from_name("Tdi Kriss Vector Gen2 45 Acp Submachine Gun Default")
  end

  test "parses caliber from slug" do
    assert_equal "7.62x39mm", Item.parse_caliber_from_name("kalashnikov-ak-103-762x39-assault-rifle-default")
  end

  test "parses shotgun gauge from name" do
    assert_equal "12/70", Item.parse_caliber_from_name("MP-153 12ga semi-automatic shotgun")
  end

  test "returns nil for name without caliber" do
    assert_nil Item.parse_caliber_from_name("Digital secure DSP radio transmitter")
  end

  test "returns nil for blank name" do
    assert_nil Item.parse_caliber_from_name(nil)
    assert_nil Item.parse_caliber_from_name("")
  end

  test "prefers longest caliber match to avoid false positives" do
    # "7.62x51" must not match as "7.62x39" or partial "62x5"
    assert_equal "7.62x51mm NATO", Item.parse_caliber_from_name("DS Arms SA58 7.62x51 assault rifle")
  end

  test "populates data caliber for preset items missing it" do
    item = Item::Generic.create!(
      bsg_id: "calparse-#{SecureRandom.hex(4)}",
      full_name: "Test Gun 9X19 Submachine Gun Default",
      short_name: "TG",
      categories: [ "preset" ]
    )
    Item.populate_calibers_from_names
    item.reload
    assert_equal "9x19mm Parabellum", item.data["caliber"]
  ensure
    item&.destroy
  end

  test "does not overwrite existing caliber data" do
    item = Item::Generic.create!(
      bsg_id: "calparse2-#{SecureRandom.hex(4)}",
      full_name: "Test Gun 9X19 Submachine Gun Default",
      short_name: "TG",
      categories: [ "preset" ],
      data: { "caliber" => "9x39mm" }
    )
    Item.populate_calibers_from_names
    item.reload
    assert_equal "9x39mm", item.data["caliber"]
  ensure
    item&.destroy
  end
end
