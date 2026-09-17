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

  test "site menu is a native disclosure" do
    get items_url

    assert_response :success
    assert_select "details.site-menu summary[aria-label=Menu]"
    assert_select "details.site-menu a[href=?]", items_path
    assert_select "details.site-menu a[href=?]", tasks_path
    assert_select "details.site-menu a[href=?]", favorites_path
  end

  test "the layout states when the reference data last changed" do
    get items_url

    assert_response :success
    assert_select "time[datetime]", minimum: 1
    assert_match(/data updated/, response.body)
  end

  test "should get show" do
    get item_url(@item)
    assert_response :success
  end

  test "show renders only http(s) links, never a stored javascript: URL" do
    @item.update!(links: [ "https://tarkov.dev/item/test-item", "javascript:alert(1)" ])

    get item_url(@item)

    assert_response :success
    assert_select "a.chip--link[href=?]", "https://tarkov.dev/item/test-item"
    assert_select "a[href=?]", "javascript:alert(1)", count: 0
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
    # Stats live in a readout directly under the item name, with no heading.
    assert_select ".readout"
    assert_select "dt", text: "Caliber"
    assert_select "dd", text: "5.45x39mm"
    assert_select "dt", text: "Default Ammo"
    assert_select "dt", text: "Ergonomics"
    assert_select "dt", text: "Recoil"
    # fire_modes / sightrange / effective_distance are not in the imported
    # weapon data, so the readout no longer claims to show them.
    assert_select "dt", text: "Fire Modes", count: 0
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
    assert_select "dt", text: "Durability"
    # Zone coverage is surfaced now; a legacy `armor_slots` integer must not
    # be mistaken for the real array-of-hashes structure.
    assert_select "dt", text: "Zones covered"
    assert_select "dt", text: "Plate slots", count: 0
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

  test "show draws no stats frame when the stats partial has nothing to render" do
    # A key carries only type/categories in the imported data, and a bare item
    # carries nothing. The frame must not be drawn around an empty partial.
    # Annotations are on in development, so they are on here too — they are
    # what made an empty partial look like it had content.
    bare = Item.create!(bsg_id: "bare-#{SecureRandom.hex(4)}", full_name: "Bare", short_name: "B")
    key = Item::Key.create!(
      bsg_id: "ktype-#{SecureRandom.hex(4)}",
      full_name: "Key With Type Only",
      short_name: "KTO",
      data: { "type" => "Key", "types" => [ "keys" ] }
    )

    annotations = ActionView::Base.annotate_rendered_view_with_filenames
    ActionView::Base.annotate_rendered_view_with_filenames = true
    [ bare, key ].each do |item|
      get item_url(item)
      assert_response :success
      assert_select ".readout", count: 0
      assert_select "dt", count: 0
    end
  ensure
    ActionView::Base.annotate_rendered_view_with_filenames = annotations
    Item.where(id: [ bare&.id, key&.id ]).delete_all
  end

  test "show lists named build variants for a weapon" do
    part = Item.create!(bsg_id: "var-part-#{SecureRandom.hex(4)}", full_name: "Kobra Sight", short_name: "Kobra")
    weapon = Item::Weapon.create!(
      bsg_id: "var-w-#{SecureRandom.hex(4)}",
      full_name: "AS VAL",
      short_name: "VAL",
      data: {
        "caliber" => "9x39mm",
        "weapon_variants" => [ { "name" => "AS VAL Kobra", "attachments" => [ part.bsg_id ] } ]
      }
    )

    get item_url(weapon)

    assert_response :success
    assert_select "section[aria-labelledby=variants-head]" do
      assert_select "h2", text: "Build variants"
      assert_select ".srcrow", text: /AS VAL Kobra/
      assert_select "a[href=?]", item_path(part), text: "Kobra Sight"
    end
  ensure
    weapon&.destroy
    part&.destroy
  end

  test "show lists the barters and crafts the item feeds" do
    item = Item.create!(bsg_id: "used-#{SecureRandom.hex(4)}", full_name: "Used Test Item", short_name: "UTI")
    product = Item.create!(bsg_id: "used-p-#{SecureRandom.hex(4)}", full_name: "Output Widget", short_name: "OW")
    task = Task.create!(bsg_id: "used-t-#{SecureRandom.hex(4)}", full_name: "Used Task", name: "used-task", given_by: "Prapor")

    barter = product.item_barters.create!(trader: "Prapor", trader_level: "2", item_name: product.full_name, task: task)
    barter.item_barter_requirements.create!(item: item, item_name: item.full_name, count: 5)

    craft = product.item_hideouts.create!(station: "Workbench", level: 2, task: task)
    craft.item_hideout_requirements.create!(item: item, item_name: item.full_name, count: 1)

    quest = Task.create!(bsg_id: "used-o-#{SecureRandom.hex(4)}", full_name: "Hand-in Quest", name: "hand-in-quest", given_by: "Therapist")
    objective = quest.task_objectives.create!(objective_type: "giveItem", description: "Hand over items", count: 2)
    objective.task_objective_items.create!(item: item, item_name: item.full_name)

    get item_url(item)

    assert_response :success
    assert_select "section[aria-labelledby=used-in-head]" do
      assert_select "h2", text: "Used in"
      assert_select ".srcrow", text: /gives Output Widget/
      assert_select ".srcrow", text: /Prapor LL2/
      assert_select ".srcrow", text: /needs 5 × UTI/
      assert_select ".srcrow", text: /crafts into Output Widget/
      assert_select ".srcrow", text: /Workbench Lv\.2/
      assert_select ".srcrow", text: /needs 1 × UTI/
      assert_select ".srcrow", text: /Hand-in Quest/
      assert_select ".srcrow", text: /Hand over items/
    end
  ensure
    product&.destroy
    quest&.destroy
    item&.destroy
    task&.destroy
  end

  test "show gives melee damage a home" do
    # Melee weapons are Item::Generic, so their damage had nowhere to render.
    melee = Item.create!(bsg_id: "melee-#{SecureRandom.hex(4)}", full_name: "MPL-50", short_name: "MPL",
                         data: { "type" => "Melee weapon", "stab_damage" => 43, "slash_damage" => 24 })

    get item_url(melee)

    assert_response :success
    assert_select "dt", text: "Stab Damage"
    assert_select "dd", text: "43"
    assert_select "dt", text: "Slash Damage"
    assert_select "dd", text: "24"
  ensure
    melee&.destroy
  end

  test "show links a preset to the item it is built from" do
    base = Item.create!(bsg_id: "base-#{SecureRandom.hex(4)}", full_name: "AK-74N", short_name: "AK")
    preset = Item.create!(bsg_id: "preset-#{SecureRandom.hex(4)}", full_name: "AK-74N Default", short_name: "AKD",
                          categories: [ "preset" ], data: { "base_item" => base.bsg_id })

    get item_url(preset)

    assert_response :success
    assert_select "dt", text: "Base item"
    assert_select "a[href=?]", item_path(base), text: "AK-74N"
  ensure
    preset&.destroy
    base&.destroy
  end

  test "show links a weapon to its default preset" do
    preset = Item.create!(bsg_id: "dp-#{SecureRandom.hex(4)}", full_name: "SCAR-L Default", short_name: "SCARD")
    weapon = Item::Weapon.create!(bsg_id: "w-#{SecureRandom.hex(4)}", full_name: "SCAR-L", short_name: "SCAR",
                                  data: { "caliber" => "Caliber556x45NATO", "default_preset" => preset.bsg_id })

    get item_url(weapon)

    assert_response :success
    assert_select "dt", text: "Default preset"
    assert_select "a[href=?]", item_path(preset), text: "SCAR-L Default"
  ensure
    weapon&.destroy
    preset&.destroy
  end

  test "show counts the plates an armor ships with" do
    armor = Item::Armor.create!(bsg_id: "pl-#{SecureRandom.hex(4)}", full_name: "Plated Vest", short_name: "PV",
                                data: { "class" => 5, "default_plates" => "2x {{id}}<br/>2x {{id2}}" })

    get item_url(armor)

    assert_response :success
    assert_select "dt", text: "Ships with"
    assert_select "dd", text: "4 plates"
  ensure
    armor&.destroy
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

    # Timeline nodes include each task name (in reverse order, root first)
    assert_select ".timeline-node", text: /Wet Job Part 1/
    assert_select ".timeline-node", text: /The Guide/
    assert_select ".timeline-node", text: /The Cleaner/

    # Per-node requirements rendered
    assert_select ".timeline-node .font-data", minimum: 1, text: /lvl 14/
    assert_select ".timeline-node .font-data", text: /LL4/
    assert_select ".timeline-node .font-data", text: /Peacekeeper LL3/

    assert_select "h2", text: /How to unlock/
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

    # Inline timeline rendered under the Where to Get sub-block
    assert_select ".timeline-node", minimum: 1
    assert_select ".timeline-node", text: /Wet Job Part 1/
    assert_select ".timeline-node", text: /The Cleaner/
    # Inline Task-gated indicator
    assert_select ".timeline-node .font-data", text: /lvl 14/
    assert_select ".timeline-node .font-data", text: /Peacekeeper LL3/
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

  test "show names the gating quest when a task-gated currency carries its task" do
    item = Item.create!(bsg_id: "tc-#{SecureRandom.hex(4)}", full_name: "Task Currency", short_name: "TC")
    prereq = Task.create!(bsg_id: "tcp-#{SecureRandom.hex(4)}", full_name: "Prereq Quest", name: "prereq-quest", given_by: "Prapor")
    gating = Task.create!(bsg_id: "tcg-#{SecureRandom.hex(4)}", full_name: "Gating Quest", name: "gating-quest", given_by: "Therapist")
    requirement = gating.requirements.create!(player_level: 0, trader_level: [])
    requirement.previous_tasks.create!(task: prereq, task_name: prereq.name)

    item.item_currencies.create!(trader: "Therapist", currency: "RUB", min_trader_level: 2,
                                 task_unlock: true, task: gating)

    get item_url(item)

    assert_response :success
    # The unlock panel names the quest and draws its chain...
    assert_select ".srcrow__title a", text: /Gating Quest/
    assert_select ".timeline-node", text: /Prereq Quest/
    # ...instead of the "quest not recorded" fallback.
    assert_no_match "not recorded", response.body
  ensure
    item&.item_currencies&.destroy_all
    PreviousTask.where(task_id: [ prereq&.id, gating&.id ]).update_all(task_id: nil)
    gating&.requirements&.destroy_all
    [ prereq, gating ].each { |t| t&.destroy }
    item&.destroy
  end

  test "show falls back to 'not recorded' when a task-gated currency has no task" do
    item = Item.create!(bsg_id: "tu-#{SecureRandom.hex(4)}", full_name: "Unknown Gate", short_name: "UG")
    item.item_currencies.create!(trader: "Peacekeeper", currency: "USD", min_trader_level: 3, task_unlock: true)

    get item_url(item)

    assert_response :success
    assert_select ".srcrow__title", text: /Task-gated trader offer/
    assert_match "the quest is not recorded", response.body
  ensure
    item&.item_currencies&.destroy_all
    item&.destroy
  end

  test "show renders the trader offer price and buy limit" do
    item = Item.create!(bsg_id: "pr-#{SecureRandom.hex(4)}", full_name: "Priced Item", short_name: "PI")
    item.item_currencies.create!(trader: "Mechanic", currency: "RUB", min_trader_level: 3,
                                 price: 22_997, price_rub: 22_997, buy_limit: 5)

    get item_url(item)

    assert_response :success
    assert_match "22,997 RUB", response.body
    assert_match "Buy limit 5 per reset", response.body
    assert_select "a[href=?]", trader_path("mechanic"), text: "Mechanic"
  ensure
    item&.item_currencies&.destroy_all
    item&.destroy
  end

  test "show renders barter and craft recipes" do
    item = Item.create!(bsg_id: "br-#{SecureRandom.hex(4)}", full_name: "Recipe Item", short_name: "RI")
    input = Item.create!(bsg_id: "br-in-#{SecureRandom.hex(4)}", full_name: "Input Widget", short_name: "IW")
    barter = item.item_barters.create!(trader: "Prapor", trader_level: "2", item_name: item.full_name,
                                       count: 2, buy_limit: 3)
    barter.item_barter_requirements.create!(item: input, item_name: input.full_name, count: 4)
    craft = item.item_hideouts.create!(station: "Workbench", level: 2, count: 6, duration: 8200)
    craft.item_hideout_requirements.create!(item: input, item_name: input.full_name, count: 1, is_tool: true)

    get item_url(item)

    assert_response :success
    assert_match "for Input Widget ×4", response.body
    assert_match "Buy limit 3 per reset", response.body
    assert_select "a[href=?]", station_path("workbench"), text: "Workbench"
    assert_match "tools needed: Input Widget", response.body
    assert_match "about 2 hours", response.body
  ensure
    item&.destroy
    input&.destroy
  end

  test "show renders item weight and grid size" do
    item = Item.create!(bsg_id: "ph-#{SecureRandom.hex(4)}", full_name: "Heavy Item", short_name: "HI",
                        data: { "weight" => 3.5, "width" => 2, "height" => 1, "stack_max_size" => 1 })

    get item_url(item)

    assert_response :success
    assert_match "3.5 kg", response.body
    assert_match "2 × 1 slots", response.body
  ensure
    item&.destroy
  end

  test "show renders slots and where a mod fits" do
    weapon = Item.create!(bsg_id: "sl-#{SecureRandom.hex(4)}", full_name: "Slot Weapon", short_name: "SW")
    mods = Array.new(8) do |i|
      Item.create!(bsg_id: "sl-m#{i}-#{SecureRandom.hex(4)}", full_name: "Slot Mod #{i}", short_name: "SM#{i}")
    end
    slot = weapon.item_slots.create!(slot_id: "s1", name: "Magazine", required: true, position: 0)
    mods.each { |mod| slot.item_slot_allowed_items.create!(item: mod) }

    get item_url(weapon)

    assert_response :success
    assert_select "h2", text: "Slots"
    assert_select "a[href=?]", item_path(mods.first), text: "Slot Mod 0"
    # The rest collapse behind a disclosure instead of being dropped.
    assert_select "details.disclosure summary", text: /and 2 more/
    assert_select "a[href=?]", item_path(mods[6]), text: "Slot Mod 6"

    get item_url(mods.first)

    assert_response :success
    assert_select "a[href=?]", item_path(weapon), text: "Slot Weapon"
    assert_match "Magazine", response.body
  ensure
    weapon&.destroy
    mods&.each(&:destroy)
  end

  test "show lists the quests that need this item as a key" do
    key = Item.create!(bsg_id: "key-#{SecureRandom.hex(4)}", full_name: "Dorm Key", short_name: "DK")
    task = Task.create!(bsg_id: "key-t-#{SecureRandom.hex(4)}", full_name: "Key Quest", name: "key-quest",
                        given_by: "Prapor",
                        needed_keys: [ { "map_name" => "Customs", "item_id" => key.id,
                                         "item_name" => key.full_name } ])

    get item_url(key)

    assert_response :success
    assert_select ".srcrow", text: /Key Quest/
    assert_select ".srcbadge", text: "Key"
  ensure
    task&.destroy
    key&.destroy
  end

  test "show lists what the item contains" do
    part = Item.create!(bsg_id: "ct-part-#{SecureRandom.hex(4)}", full_name: "Build Part", short_name: "BP")
    preset = Item.create!(bsg_id: "ct-#{SecureRandom.hex(4)}", full_name: "Build Preset", short_name: "BPreset",
                          data: { "containsItems" => [ { "item" => part.bsg_id, "count" => 2 } ] })

    get item_url(preset)

    assert_response :success
    assert_select "section[aria-labelledby=contains-head]" do
      assert_select "h2", text: "Contains"
      assert_select "a[href=?]", item_path(part), text: "Build Part"
    end
    assert_match "×2", response.body
  ensure
    preset&.destroy
    part&.destroy
  end

  test "index table shows the item weight" do
    item = Item.create!(bsg_id: "wt-#{SecureRandom.hex(4)}", full_name: "Weight Row", short_name: "WR",
                        data: { "weight" => 1.25 })

    get items_url(q: "Weight Row")

    assert_response :success
    assert_select "td", text: "1.25 kg"
  ensure
    item&.destroy
  end

  test "show collapses a long list of fitting slots" do
    mod = Item.create!(bsg_id: "fit-#{SecureRandom.hex(4)}", full_name: "Popular Mod", short_name: "PM")
    weapons = Array.new(13) do |i|
      weapon = Item.create!(bsg_id: "fit-w#{i}-#{SecureRandom.hex(4)}", full_name: "Fit Weapon #{i}", short_name: "FW#{i}")
      weapon.item_slots.create!(slot_id: "s#{i}", name: "Mount", position: 0)
            .item_slot_allowed_items.create!(item: mod)
      weapon
    end

    get item_url(mod)

    assert_response :success
    assert_select "details.disclosure summary", text: /and 1 more slots/
  ensure
    weapons&.each(&:destroy)
    mod&.destroy
  end

  # --- typeahead ---

  test "search suggests matching items as rows" do
    item = Item.create!(bsg_id: "ta-#{SecureRandom.hex(4)}", full_name: "Alpha Autocomplete", short_name: "AA")

    get search_items_url(q: "alpha autocomplete")

    assert_response :success
    assert_select "a[href=?]", item_path(item)
    assert_match "Alpha Autocomplete", response.body
  ensure
    item&.destroy
  end

  test "search ignores a query shorter than the minimum" do
    get search_items_url(q: "a")
    assert_response :no_content

    get search_items_url
    assert_response :no_content
  end

  test "search returns no content when nothing matches" do
    get search_items_url(q: "zzzzzzzzzzzz")
    assert_response :no_content
  end

  test "search caps how many suggestions it returns" do
    created = Array.new(ItemsController::AUTOCOMPLETE_LIMIT + 4) do |i|
      Item.create!(bsg_id: "cap-#{i}-#{SecureRandom.hex(4)}", full_name: "Cap Suggestion #{i}", short_name: "CS#{i}")
    end

    get search_items_url(q: "cap suggestion")

    assert_response :success
    assert_select "a", maximum: ItemsController::AUTOCOMPLETE_LIMIT
  ensure
    Item.where(id: created&.map(&:id)).delete_all
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

    assert_select "p", text: /Task-gated trader offer/
    assert_select "p", text: /quest is not recorded/
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

  test "index filters by trader" do
    prapor_item = Item.create!(bsg_id: "tr1-#{SecureRandom.hex(4)}", full_name: "Prapor Only Item", short_name: "POI")
    therapist_item = Item.create!(bsg_id: "tr2-#{SecureRandom.hex(4)}", full_name: "Therapist Only Item", short_name: "TOI")
    prapor_item.item_currencies.create!(trader: "Prapor", currency: "RUB", min_trader_level: 1)
    therapist_item.item_currencies.create!(trader: "Therapist", currency: "RUB", min_trader_level: 1)

    get items_url(filters: { trader: [ "Prapor" ] })

    assert_response :success
    assert_select "td a", text: "Prapor Only Item"
    assert_no_match(/Therapist Only Item/, response.body)
  ensure
    ItemCurrency.destroy_all
    [ prapor_item, therapist_item ].each { |i| i&.destroy }
  end

  test "index sorts by weight" do
    heavy = Item.create!(bsg_id: "sw-h-#{SecureRandom.hex(4)}", full_name: "Weighs A Lot", short_name: "WAL",
                         data: { "weight" => 9.9 })
    light = Item.create!(bsg_id: "sw-l-#{SecureRandom.hex(4)}", full_name: "Weighs A Little", short_name: "WALt",
                         data: { "weight" => 0.1 })

    get items_url(q: "Weighs A", sort: "weight_asc")

    assert_response :success
    assert_operator response.body.index("Weighs A Little"), :<, response.body.index("Weighs A Lot")
  ensure
    [ heavy, light ].each { |i| i&.destroy }
  end

  test "index sorts by weight when a filter adds DISTINCT" do
    light = Item.create!(bsg_id: "dw1-#{SecureRandom.hex(4)}", full_name: "Distinct Light", short_name: "DL",
                         data: { "weight" => 0.2 })
    heavy = Item.create!(bsg_id: "dw2-#{SecureRandom.hex(4)}", full_name: "Distinct Heavy", short_name: "DH",
                         data: { "weight" => 7.7 })
    [ light, heavy ].each do |item|
      item.item_currencies.create!(trader: "Prapor", currency: "RUB", min_trader_level: 1)
    end

    get items_url(filters: { trader: [ "Prapor" ] }, sort: "weight_desc")

    assert_response :success
    assert_operator response.body.index("Distinct Heavy"), :<, response.body.index("Distinct Light")
  ensure
    ItemCurrency.destroy_all
    [ light, heavy ].each { |i| i&.destroy }
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
    item = Item.create!(bsg_id: "pill-#{SecureRandom.hex(4)}", full_name: "Pill Test Item", short_name: "PTI")
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
    ref_item = Item.create!(bsg_id: "ref1-#{SecureRandom.hex(4)}", full_name: "Ref Item", short_name: "RF")
    other_item = Item.create!(bsg_id: "ref2-#{SecureRandom.hex(4)}", full_name: "Other Item", short_name: "OI")
    ref_item.item_currencies.create!(trader: "Ref", currency: "EUR", min_trader_level: 1)
    other_item.item_currencies.create!(trader: "Prapor", currency: "RUB", min_trader_level: 1)

    get items_url(filters: { exclude_ref: [ "1" ] })
    assert_response :success
    assert_select "td a", text: "Other Item"
    assert_no_match(/Ref Item/, response.body)

    # Without the filter both show
    get items_url
    assert_select "td a", text: "Ref Item"
  ensure
    ItemCurrency.destroy_all
    [ ref_item, other_item ].each { |i| i&.destroy }
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

  test "index caliber filter also matches ammo packs by their category" do
    loose = Item::Ammo.create!(bsg_id: "calp1-#{SecureRandom.hex(4)}", full_name: "5.45x39mm BT", short_name: "BT", data: { "caliber" => "5.45x39mm" })
    other = Item::Ammo.create!(bsg_id: "calp2-#{SecureRandom.hex(4)}", full_name: "7.62x39mm PS", short_name: "PS", data: { "caliber" => "7.62x39mm" })
    pack = Item.create!(bsg_id: "calp3-#{SecureRandom.hex(4)}", full_name: "5.45x39mm BT ammo pack", short_name: "BTP", categories: [ "ammobox", "5.45x39mm_pack" ])

    get items_url(filters: { caliber: [ "5.45x39mm" ] })
    assert_response :success
    assert_select "td a", text: "5.45x39mm BT"
    assert_select "td a", text: "5.45x39mm BT ammo pack"
    assert_no_match(/7.62x39mm PS/, response.body)
  ensure
    [ loose, other, pack ].each { |i| i&.destroy }
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

  test "index source 'craft' means quest reward, not hideout craft" do
    rewarded = Item.create!(bsg_id: "srcq1-#{SecureRandom.hex(4)}", full_name: "Rewarded Item", short_name: "RI")
    crafted = Item.create!(bsg_id: "srcq2-#{SecureRandom.hex(4)}", full_name: "Crafted Item", short_name: "CI")
    task = Task.create!(bsg_id: "t-srcq-#{SecureRandom.hex(4)}", full_name: "Reward Task", name: "reward-task", given_by: "Prapor")
    rewarded.item_task_rewards.create!(task_id: task.id, task_name: task.name)
    crafted.item_hideouts.create!(station: "Workbench", level: 1)

    get items_url(filters: { source: [ "craft" ] })

    assert_response :success
    assert_select "td a", text: "Rewarded Item"
    assert_no_match(/Crafted Item/, response.body)
  ensure
    crafted&.item_hideouts&.destroy_all
    [ rewarded, crafted ].each { |i| i&.destroy }
    task&.destroy
  end

  test "index marks task-gated item cards" do
    gated = Item.create!(bsg_id: "badge-#{SecureRandom.hex(4)}", full_name: "Badge Gated", short_name: "BG")
    free = Item.create!(bsg_id: "badge2-#{SecureRandom.hex(4)}", full_name: "Badge Free", short_name: "BF")
    task = Task.create!(bsg_id: "badge-t-#{SecureRandom.hex(4)}", full_name: "Badge Task", name: "badge-task", given_by: "Prapor")
    reward = task.rewards.create!(reward_type: "finish_rewards")
    reward.offer_unlocks.create!(item_id: gated.id, item_name: gated.full_name, trader_name: "Prapor", trader_level: 1)

    get items_url(q: "Badge")

    assert_response :success
    assert_select "a.card[href=?]", item_path(gated) do
      assert_select ".chip", text: "Task-gated"
    end
    assert_select "a.card[href=?]", item_path(free) do
      assert_select ".chip", text: "Task-gated", count: 0
    end
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
