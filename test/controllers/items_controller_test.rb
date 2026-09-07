require "test_helper"

class ItemsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @item = Item.create!(bsg_id: "test123", full_name: "Test Item", short_name: "TI")
  end

  def teardown
    @item.destroy if @item
  end

  test "should get index" do
    get items_url
    assert_response :success
  end

  test "should get show" do
    get item_url(@item)
    assert_response :success
  end

  # --- per-type stat partials (Task 8) ---

  test "show renders weapon stats partial for Item::Weapon" do
    weapon = Item::Weapon.create!(
      bsg_id: "w-#{SecureRandom.hex(4)}",
      full_name: "AK-74M",
      short_name: "AK-74M",
      data: {
        "caliber" => "5.45x39mm",
        "default_ammo" => "BS",
        "fire_modes" => [ "single", "fullauto" ],
        "ergonomics" => 50,
        "recoil" => 100,
        "sightrange" => 100,
        "velocity" => 880,
        "effective_distance" => 200
      }
    )
    get item_url(weapon)
    assert_response :success
    assert_select "h2", text: /Details/
    assert_select "dt", text: "Caliber"
    assert_select "dd", text: "5.45x39mm"
    assert_select "dt", text: "Default Ammo"
    assert_select "dt", text: "Fire Modes"
    assert_select "dt", text: "Ergonomics"
    assert_select "dt", text: "Recoil"
  ensure
    weapon&.destroy
  end

  test "show renders ammo stats partial for Item::Ammo" do
    ammo = Item::Ammo.create!(
      bsg_id: "a-#{SecureRandom.hex(4)}",
      full_name: "BS Ammo",
      short_name: "BS",
      data: {
        "caliber" => "5.45x39mm",
        "damage" => 50,
        "penetration_power" => 37,
        "ammo_type" => "Round",
        "stack_max_size" => 60,
        "tracer" => true
      }
    )
    get item_url(ammo)
    assert_response :success
    assert_select "dt", text: "Caliber"
    assert_select "dt", text: "Damage"
    assert_select "dt", text: "Penetration"
    assert_select "dt", text: "Ammo Type"
    assert_select "dt", text: "Stack Max Size"
  ensure
    ammo&.destroy
  end

  test "show renders armor stats partial for Item::Armor" do
    armor = Item::Armor.create!(
      bsg_id: "ar-#{SecureRandom.hex(4)}",
      full_name: "Trooper",
      short_name: "TR",
      data: {
        "class" => "4",
        "armor_type" => "Body Armor",
        "armor_slots" => 4,
        "zones" => [ "Thorax", "Stomach" ],
        "max_uses" => 50
      }
    )
    get item_url(armor)
    assert_response :success
    assert_select "dt", text: "Armor Class"
    assert_select "dd", text: "4"
    assert_select "dt", text: "Armor Type"
    assert_select "dt", text: "Armor Slots"
    assert_select "dt", text: "Zones"
    assert_select "dt", text: "Durability"
  ensure
    armor&.destroy
  end

  test "show renders key stats partial for Item::Key" do
    key = Item::Key.create!(
      bsg_id: "k-#{SecureRandom.hex(4)}",
      full_name: "Key",
      short_name: "K",
      data: { "max_uses" => 25 }
    )
    get item_url(key)
    assert_response :success
    assert_select "dt", text: "Max Uses"
  ensure
    key&.destroy
  end

  test "show renders magazine stats partial for Item::Magazine" do
    mag = Item::Magazine.create!(
      bsg_id: "m-#{SecureRandom.hex(4)}",
      full_name: "Mag",
      short_name: "M",
      data: { "caliber" => "5.45x39mm", "capacity" => 30 }
    )
    get item_url(mag)
    assert_response :success
    assert_select "dt", text: "Caliber"
    assert_select "dt", text: "Capacity"
  ensure
    mag&.destroy
  end

  test "show renders container stats partial for Item::Container" do
    container = Item::Container.create!(
      bsg_id: "c-#{SecureRandom.hex(4)}",
      full_name: "Case",
      short_name: "C",
      data: { "default" => true }
    )
    get item_url(container)
    assert_response :success
    assert_select "dt", text: "Default Container"
  ensure
    container&.destroy
  end

  test "show renders medical stats partial for Item::Medical" do
    med = Item::Medical.create!(
      bsg_id: "md-#{SecureRandom.hex(4)}",
      full_name: "MedKit",
      short_name: "MED",
      data: { "max_uses" => 1, "effect" => "Heal", "use_time" => 3 }
    )
    get item_url(med)
    assert_response :success
    assert_select "dt", text: "Max Uses"
    assert_select "dt", text: "Effect"
    assert_select "dt", text: "Use Time"
  ensure
    med&.destroy
  end

  test "show renders provision stats partial for Item::Provision" do
    prov = Item::Provision.create!(
      bsg_id: "pr-#{SecureRandom.hex(4)}",
      full_name: "MRE",
      short_name: "MRE",
      data: { "effect" => "Energy", "use_time" => 5 }
    )
    get item_url(prov)
    assert_response :success
    assert_select "dt", text: "Effect"
    assert_select "dt", text: "Use Time"
  ensure
    prov&.destroy
  end

  test "show renders throwable stats partial for Item::Throwable" do
    thr = Item::Throwable.create!(
      bsg_id: "th-#{SecureRandom.hex(4)}",
      full_name: "Grenade",
      short_name: "G",
      data: { "type" => "Fragmentation", "effect" => "Explosive" }
    )
    get item_url(thr)
    assert_response :success
    assert_select "dt", text: "Type"
    assert_select "dt", text: "Effect"
  ensure
    thr&.destroy
  end

  test "show renders generic stats partial for Item::Generic" do
    gen = Item::Generic.create!(
      bsg_id: "gn-#{SecureRandom.hex(4)}",
      full_name: "Generic Item",
      short_name: "GI",
      data: {}
    )
    get item_url(gen)
    assert_response :success
    # Generic partial only shows name info (no type-specific dts), so just verify no error
    assert_select "h1", text: /Generic Item/
  ensure
    gen&.destroy
  end

  test "show handles item with no data without error" do
    bare = Item.create!(
      bsg_id: "bare-#{SecureRandom.hex(4)}",
      full_name: "Bare",
      short_name: "B"
    )
    get item_url(bare)
    assert_response :success
  ensure
    bare&.destroy
  end
end
