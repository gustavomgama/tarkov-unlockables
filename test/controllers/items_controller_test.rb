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

  # --- Ransack search ---

  test "index search by full_name returns matching items" do
    alpha = Item.create!(bsg_id: "alpha-#{SecureRandom.hex(4)}", full_name: "Alpha Scope", short_name: "AS")
    beta = Item.create!(bsg_id: "beta-#{SecureRandom.hex(4)}", full_name: "Beta Grip", short_name: "BG")

    get items_url(q: "Alpha")

    assert_response :success
    assert_select "td a", text: "Alpha Scope"
    assert_no_match(/Beta Grip/, response.body)
  ensure
    [ alpha, beta ].each { |i| i&.destroy }
  end

  test "index search by short_name returns matching items" do
    alpha = Item.create!(bsg_id: "alpha2-#{SecureRandom.hex(4)}", full_name: "Alpha Scope 2", short_name: "ALF")
    beta = Item.create!(bsg_id: "beta2-#{SecureRandom.hex(4)}", full_name: "Beta Grip 2", short_name: "BTA")

    get items_url(q: "ALF")

    assert_response :success
    assert_select "td", text: "ALF"
    assert_no_match(/BTA/, response.body)
  ensure
    [ alpha, beta ].each { |i| i&.destroy }
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

  # --- Filter tests ---

  test "index filters by currency" do
    rub_item = Item.create!(bsg_id: "cur1-#{SecureRandom.hex(4)}", full_name: "Ruble Item", short_name: "RI")
    usd_item = Item.create!(bsg_id: "cur2-#{SecureRandom.hex(4)}", full_name: "Dollar Item", short_name: "DI")
    rub_item.item_currencies.create!(trader: "Prapor", currency: "RUB", min_trader_level: 1)
    usd_item.item_currencies.create!(trader: "Peacekeeper", currency: "USD", min_trader_level: 2)

    get items_url(filters: { currency: [ "RUB" ] })
    assert_response :success
    assert_select "td a", text: "Ruble Item"
    assert_no_match(/Dollar Item/, response.body)
  ensure
    ItemCurrency.destroy_all
    [ rub_item, usd_item ].each { |i| i&.destroy }
  end

  test "index filters by category" do
    head_item = Item.create!(bsg_id: "cat1-#{SecureRandom.hex(4)}", full_name: "Headphones Pro", short_name: "HP", categories: [ "headphones" ])
    gun_item = Item.create!(bsg_id: "cat2-#{SecureRandom.hex(4)}", full_name: "AK-74", short_name: "AK", categories: [ "assault_rifles" ])

    get items_url(filters: { category: [ "headphones" ] })
    assert_response :success
    assert_select "td a", text: "Headphones Pro"
    assert_no_match(/AK-74/, response.body)
  ensure
    [ head_item, gun_item ].each { |i| i&.destroy }
  end

  test "index filters by caliber" do
    ammo545 = Item::Ammo.create!(bsg_id: "cal1-#{SecureRandom.hex(4)}", full_name: "5.45x39mm BP", short_name: "BP", data: { "caliber" => "5.45x39mm", "damage" => 40 })
    ammo762 = Item::Ammo.create!(bsg_id: "cal2-#{SecureRandom.hex(4)}", full_name: "7.62x39mm PS", short_name: "PS", data: { "caliber" => "7.62x39mm", "damage" => 50 })

    get items_url(filters: { caliber: [ "5.45x39mm" ] })
    assert_response :success
    assert_select "td a", text: "5.45x39mm BP"
    assert_no_match(/7.62x39mm PS/, response.body)
  ensure
    [ ammo545, ammo762 ].each { |i| i&.destroy }
  end

  test "index filters by armor class" do
    armor4 = Item::Armor.create!(bsg_id: "arm1-#{SecureRandom.hex(4)}", full_name: "Trooper Class 4", short_name: "T4", data: { "class" => "4" })
    armor6 = Item::Armor.create!(bsg_id: "arm2-#{SecureRandom.hex(4)}", full_name: "Zabralo Class 6", short_name: "Z6", data: { "class" => "6" })

    get items_url(filters: { armor_class: [ "4" ] })
    assert_response :success
    assert_select "td a", text: "Trooper Class 4"
    assert_no_match(/Zabralo Class 6/, response.body)
  ensure
    [ armor4, armor6 ].each { |i| i&.destroy }
  end

  test "index filters by task_required" do
    gated = Item.create!(bsg_id: "tg1-#{SecureRandom.hex(4)}", full_name: "Task Gated Item", short_name: "TGI")
    free = Item.create!(bsg_id: "tg2-#{SecureRandom.hex(4)}", full_name: "Free Item", short_name: "FI")
    task = Task.create!(bsg_id: "t-tg-#{SecureRandom.hex(4)}", full_name: "Gate Task", name: "gate-task", given_by: "Prapor")
    reward = task.rewards.create!(reward_type: "finish_rewards")
    reward.offer_unlocks.create!(item_id: gated.id, item_name: gated.full_name, trader_name: "Prapor", trader_level: 1)

    get items_url(filters: { task_required: [ "1" ] })
    assert_response :success
    assert_select "td a", text: "Task Gated Item"
    assert_no_match(/Free Item/, response.body)
  ensure
    OfferUnlock.where(item_id: gated&.id).destroy_all
    Reward.where(task_id: task&.id).destroy_all
    task&.destroy
    [ gated, free ].each { |i| i&.destroy }
  end

  test "index handles multiple filters combined" do
    rub_head = Item.create!(bsg_id: "mf1-#{SecureRandom.hex(4)}", full_name: "Rub Head", short_name: "RH", categories: [ "headphones" ])
    rub_gun = Item.create!(bsg_id: "mf2-#{SecureRandom.hex(4)}", full_name: "Rub Gun", short_name: "RG", categories: [ "assault_rifles" ])
    usd_head = Item.create!(bsg_id: "mf3-#{SecureRandom.hex(4)}", full_name: "USD Head", short_name: "UH", categories: [ "headphones" ])
    rub_head.item_currencies.create!(trader: "Prapor", currency: "RUB", min_trader_level: 1)
    rub_gun.item_currencies.create!(trader: "Prapor", currency: "RUB", min_trader_level: 1)
    usd_head.item_currencies.create!(trader: "Peacekeeper", currency: "USD", min_trader_level: 2)

    get items_url(filters: { currency: [ "RUB" ], category: [ "headphones" ] })
    assert_response :success
    assert_select "td a", text: "Rub Head"
    assert_no_match(/Rub Gun/, response.body)
    assert_no_match(/USD Head/, response.body)
  ensure
    ItemCurrency.destroy_all
    [ rub_head, rub_gun, usd_head ].each { |i| i&.destroy }
  end

  test "index with empty filter values does not crash" do
    get items_url(filters: { currency: [ "" ], caliber: [ "" ], category: [ "" ] })
    assert_response :success
  end

  test "index filters by source task_gated" do
    gated = Item.create!(bsg_id: "src1-#{SecureRandom.hex(4)}", full_name: "Gated Source", short_name: "GS")
    free = Item.create!(bsg_id: "src2-#{SecureRandom.hex(4)}", full_name: "Free Source", short_name: "FS")
    task = Task.create!(bsg_id: "t-src-#{SecureRandom.hex(4)}", full_name: "Source Task", name: "source-task", given_by: "Prapor")
    reward = task.rewards.create!(reward_type: "finish_rewards")
    reward.offer_unlocks.create!(item_id: gated.id, item_name: gated.full_name, trader_name: "Prapor", trader_level: 1)

    get items_url(filters: { source: [ "task_gated" ] })
    assert_response :success
    assert_select "td a", text: "Gated Source"
    assert_no_match(/Free Source/, response.body)
  ensure
    OfferUnlock.where(item_id: gated&.id).destroy_all
    Reward.where(task_id: task&.id).destroy_all
    task&.destroy
    [ gated, free ].each { |i| i&.destroy }
  end

  test "index filters by source trader" do
    trader_item = Item.create!(bsg_id: "src3-#{SecureRandom.hex(4)}", full_name: "Trader Item", short_name: "TI")
    other_item = Item.create!(bsg_id: "src4-#{SecureRandom.hex(4)}", full_name: "Other Item", short_name: "OI")
    trader_item.item_currencies.create!(trader: "Prapor", currency: "RUB", min_trader_level: 1)

    get items_url(filters: { source: [ "trader" ] })
    assert_response :success
    assert_select "td a", text: "Trader Item"
    assert_no_match(/Other Item/, response.body)
  ensure
    ItemCurrency.destroy_all
    [ trader_item, other_item ].each { |i| i&.destroy }
  end

  test "index filters with source and category combined" do
    item_a = Item.create!(bsg_id: "src5-#{SecureRandom.hex(4)}", full_name: "Trader Headphone", short_name: "TH", categories: [ "headphones" ])
    item_b = Item.create!(bsg_id: "src6-#{SecureRandom.hex(4)}", full_name: "Trader Gun", short_name: "TG", categories: [ "assault_rifles" ])
    item_c = Item.create!(bsg_id: "src7-#{SecureRandom.hex(4)}", full_name: "No Trader Headphone", short_name: "NH", categories: [ "headphones" ])
    item_a.item_currencies.create!(trader: "Prapor", currency: "RUB", min_trader_level: 1)
    item_b.item_currencies.create!(trader: "Prapor", currency: "RUB", min_trader_level: 1)

    get items_url(filters: { source: [ "trader" ], category: [ "headphones" ] })
    assert_response :success
    assert_select "td a", text: "Trader Headphone"
    assert_no_match(/Trader Gun/, response.body)
    assert_no_match(/No Trader Headphone/, response.body)
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
end
