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

  # --- Task 11: prerequisite chain rendered with per-node requirements ---

  test "show renders prerequisite chain with lvl + trader requirements in How to Unlock" do
    item = Item.create!(bsg_id: "m80-#{SecureRandom.hex(4)}", full_name: "7.62x51mm M80", short_name: "M80")
    wet1 = Task.create!(bsg_id: "wet1v-#{SecureRandom.hex(4)}", full_name: "Wet Job 1", name: "wet-job-part-1", given_by: "Mechanic")
    guide = Task.create!(bsg_id: "guidev-#{SecureRandom.hex(4)}", full_name: "The Guide", name: "the-guide", given_by: "Peacekeeper")
    cleaner = Task.create!(bsg_id: "cleanv-#{SecureRandom.hex(4)}", full_name: "The Cleaner", name: "the-cleaner", given_by: "Peacekeeper")

    wet1.requirements.create!(player_level: 14, trader_level: [])
    guide_r = guide.requirements.create!(player_level: 0, trader_level: [ { "trader_name" => "", "trader_level" => "4" } ])
    guide_r.previous_tasks.create!(task: wet1, task_name: wet1.name)
    cleaner_r = cleaner.requirements.create!(player_level: 0, trader_level: [ { "trader_name" => "peacekeeper", "trader_level" => "3" } ])
    cleaner_r.previous_tasks.create!(task: guide, task_name: guide.name)

    reward = cleaner.rewards.create!(reward_type: "finish_rewards")
    reward.offer_unlocks.create!(item_id: item.id, item_name: item.full_name, trader_name: "peacekeeper", trader_level: "4")

    get item_url(item)
    assert_response :success

    # Chain pills include each task name (in reverse order, root first)
    assert_select "span", text: /wet-job-part-1/
    assert_select "span", text: /the-guide/
    assert_select "span", text: /the-cleaner/

    # Per-node requirements rendered
    assert_select ".prereq-req", minimum: 1, text: /lvl 14/
    assert_select ".prereq-req", text: /LL4/
    assert_select ".prereq-req", text: /Peacekeeper LL3/

    assert_select "h2", text: /How to Unlock/
  ensure
    OfferUnlock.where(item_id: item&.id).destroy_all
    PreviousTask.where(task_id: [ wet1&.id, guide&.id, cleaner&.id ]).update_all(task_id: nil)
    Reward.where(task_id: [ wet1&.id, guide&.id, cleaner&.id ]).destroy_all
    [ wet1, guide, cleaner ].each { |t| t&.destroy }
    item&.destroy
  end

  test "show renders inline chain under item_currency with task_unlock=true" do
    item = Item.create!(bsg_id: "m80c-#{SecureRandom.hex(4)}", full_name: "M80 Currency", short_name: "M80c")
    wet1 = Task.create!(bsg_id: "wet1c-#{SecureRandom.hex(4)}", full_name: "Wet Job 1", name: "wet-job-part-1", given_by: "Mechanic")
    cleaner = Task.create!(bsg_id: "cleanc-#{SecureRandom.hex(4)}", full_name: "The Cleaner", name: "the-cleaner", given_by: "Peacekeeper")

    wet1.requirements.create!(player_level: 14, trader_level: [])
    cleaner_r = cleaner.requirements.create!(player_level: 0, trader_level: [ { "trader_name" => "peacekeeper", "trader_level" => "3" } ])
    cleaner_r.previous_tasks.create!(task: wet1, task_name: wet1.name)

    reward = cleaner.rewards.create!(reward_type: "finish_rewards")
    reward.offer_unlocks.create!(item_id: item.id, item_name: item.full_name, trader_name: "peacekeeper", trader_level: "4")

    item.item_currencies.create!(trader: "Peacekeeper", currency: "USD", min_trader_level: 4, task_unlock: true)

    get item_url(item)
    assert_response :success

    # Inline chain rendered with class .currency-chain (the Where to Get sub-block)
    assert_select ".currency-chain", minimum: 1
    assert_select ".currency-chain span", text: /wet-job-part-1/
    assert_select ".currency-chain span", text: /the-cleaner/
    # Inline Task-gated indicator
    assert_select ".currency-chain .prereq-req", text: /lvl 14/
    assert_select ".currency-chain .prereq-req", text: /Peacekeeper LL3/
    # Badge in the row itself
    assert_select "span", text: /Task-gated/
  ensure
    OfferUnlock.where(item_id: item&.id).destroy_all
    PreviousTask.where(task_id: [ wet1&.id, cleaner&.id ]).update_all(task_id: nil)
    Reward.where(task_id: [ wet1&.id, cleaner&.id ]).destroy_all
    item&.item_currencies&.destroy_all
    [ wet1, cleaner ].each { |t| t&.destroy }
    item&.destroy
  end

  test "show renders 'unlocking task not found' for task_currency when no OfferUnlock" do
    item = Item.create!(bsg_id: "m80d-#{SecureRandom.hex(4)}", full_name: "M80d", short_name: "M80d")
    item.item_currencies.create!(trader: "Peacekeeper", currency: "USD", min_trader_level: 4, task_unlock: true)

    get item_url(item)
    assert_response :success

    assert_select ".currency-chain", text: /unlocking task not found/
  ensure
    item&.item_currencies&.destroy_all
    item&.destroy
  end
end
