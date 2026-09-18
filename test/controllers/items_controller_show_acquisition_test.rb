# The acquisition half of the item page: the panels that say where the item
# comes from and what consumes it. Page chrome and stats are in
# items_controller_show_test.rb.

require "test_helper"

class ItemsControllerShowAcquisitionTest < ActionDispatch::IntegrationTest
  include ItemsTestHelpers
  include ItemShowTestHelpers

  setup { @item = create_show_item }
  teardown { @item&.destroy }

  # A build can change a dozen parts; the row lists five and counts the rest.
  test "show counts the build-variant parts it does not list" do
    parts = 7.times.map { |i| create_item("Variant Part #{i}", short_name: "VP#{i}") }
    weapon = create_item("Variant Weapon", klass: Item::Weapon, short_name: "VW",
                         data: { "weapon_variants" => [ { "name" => "VW Build", "attachments" => parts.map(&:bsg_id) } ] })

    get_ok(item_url(weapon))

    assert_select "section[aria-labelledby=variants-head]" do
      assert_select "a", text: "Variant Part 0"
      assert_select "span", text: "+2 more"
    end
  ensure
    weapon&.destroy
    parts.each(&:destroy)
  end

  test "show lists named build variants for a weapon" do
    part = create_item("Kobra Sight", short_name: "Kobra")
    weapon = create_item("AS VAL", klass: Item::Weapon, short_name: "VAL", data: { "caliber" => "9x39mm", "weapon_variants" => [ { "name" => "AS VAL Kobra", "attachments" => [ part.bsg_id ] } ] })

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
    item = create_item("Used Test Item", short_name: "UTI")
    task = create_task("Used Task", "used-task", given_by: "Prapor")
    reward = task.rewards.create!(reward_type: "finish_rewards")

    # One barter and one craft, each with a requirement row that consumes the
    # item. The trader lives on the requirement row; the station lives on the
    # craft unlock itself (the barter row has no station column).
    build_used_in_unlock(reward, item, :barter, requirement: { trader_name: "Prapor", trader_level: 2 }, count: 5)
    build_used_in_unlock(reward, item, :craft, requirement: { trader_name: "Mechanic", trader_level: 1 },
                         unlock: { hideout_station: "Workbench", station_level: 2 }, count: 1)

    get item_url(item)

    assert_response :success
    assert_select "section[aria-labelledby=used-in-head]" do
      assert_select "h2", text: "Used in"
      assert_select ".srcrow", text: /Prapor LL2/
      assert_select ".srcrow", text: /needs 5 × UTI/
      assert_select ".srcrow", text: /Workbench Lv\.2/
      assert_select ".srcrow", text: /needs 1 × UTI/
    end
  ensure
    Reward.where(task_id: task&.id).destroy_all
    task&.destroy
    item&.destroy
  end

  test "show lists the packs and presets the item belongs to" do
    round = create_item("Packed Round", short_name: "PR")
    pack = create_item("Round Pack", short_name: "RP",
                       data: { "containsItems" => [ { "item" => round.bsg_id, "count" => 2 } ] })

    get item_url(round)

    assert_response :success
    assert_select "section[aria-labelledby=part-of-head]" do
      assert_select "h2", text: /Packs & presets/
      assert_select "a[href=?]", item_path(pack), text: /Round Pack/
      assert_select ".srcrow__meta", text: /contains 2 × PR/
    end
  ensure
    pack&.destroy
    round&.destroy
  end

  # A one-row comparison table is noise: the gate is > 1, not > 0. The pack keeps
  # the main column rendered (so the table is absent because of the gate, not
  # because the whole column was dropped) and it is why `siblings` is populated
  # at all — the caliber list is only built for an item with no accepted ammo.
  test "show omits the caliber table when the round has no peers" do
    own = create_item("Lonely Round", klass: Item::Ammo, short_name: "LR",
                      data: { "caliber" => "LonelyCal", "penetration_power" => 20 })
    pack = create_item("Lonely Pack", short_name: "LP",
                       data: { "containsItems" => [ { "item" => own.bsg_id, "count" => 1 } ] })

    get_ok(item_url(own))

    assert_select "h2", text: /Packs & presets/
    assert_select "h2", text: /Rounds in/, count: 0
  ensure
    Item.where(full_name: [ "Lonely Round", "Lonely Pack" ]).delete_all
  end

  # A 16-step wall of text buries the answer the hero already gave, so a chain
  # longer than six nodes collapses behind a disclosure.
  test "show collapses a long prerequisite chain behind a disclosure" do
    previous = nil
    8.times do |i|
      previous = create_chain_task("Long Chain #{i}", "long-chain-#{i}", given_by: "Prapor", previous: previous)
    end
    item = create_item("Long Chain Item", short_name: "LC")
    unlock_via_task(previous, item)

    get_ok(item_url(item))

    assert_select "details.disclosure summary", text: /Show all 8 steps/
    # The nodes are inside the collapsed <details>, not rendered inline.
    assert_select "details.disclosure .timeline-node", minimum: 1
    assert_select "> .timeline-node", count: 0
  ensure
    Task.where("full_name LIKE 'Long Chain %'").destroy_all
    item&.destroy
  end

  # The unlock panel links the gating quest's wiki walkthrough when the task
  # carries one (the task page has its own link; this is the item page's copy).
  test "show links the gating quest's wiki walkthrough" do
    item = create_item("Wiki Link Item", short_name: "WL")
    task = create_chain_task("Wiki Link Task", "wiki-link-task", given_by: "Prapor")
    task.update!(wiki_link: "https://example.com/wiki-link-task")
    unlock_via_task(task, item)

    get_ok(item_url(item))

    assert_select "section[aria-labelledby=unlock-head] a[href=?]", task.wiki_link,
                  text: /Quest walkthrough on the wiki/
  ensure
    destroy_unlock_fixtures(item, [ task ])
  end

  # The comparison table's whole point is the penetration column (and the armor
  # class it implies); the damage column is the fallback when it is missing.
  test "show renders the ammo comparison columns" do
    own = create_item("Table Round", klass: Item::Ammo, short_name: "TR",
                      data: { "caliber" => "TableCal", "penetration_power" => 42, "damage" => 55 })
    create_item("Table Peer", klass: Item::Ammo, short_name: "TP",
                data: { "caliber" => "TableCal", "penetration_power" => 20, "damage" => 30 })

    get_ok(item_url(own))

    assert_select ".ammo-table" do
      assert_select "td", text: "42"
      assert_select "td", text: "55"
      assert_select "td", text: "4"   # 42 penetration → armor class 4
    end
  ensure
    Item.where(full_name: [ "Table Round", "Table Peer" ]).delete_all
  end

  test "show highlights the round being viewed among its caliber" do
    own = create_item("Viewed Round", klass: Item::Ammo, short_name: "VR",
                                   data: { "caliber" => "TestCal", "penetration_power" => 20 })
    create_item("Peer Round", klass: Item::Ammo, short_name: "PR",
                data: { "caliber" => "TestCal", "penetration_power" => 40 })

    get_ok(item_url(own))

    assert_select ".ammo-table tr.current" do
      # The row header prefers the short name, so it reads "VR (viewing)".
      assert_select "a[aria-current=?]", "true", text: /VR \(viewing\)/
    end
  ensure
    Item.where(full_name: [ "Viewed Round", "Peer Round" ]).delete_all
  end

  test "show links a preset to the item it is built from" do
    base = create_item("AK-74N", short_name: "AK")
    preset = create_item("AK-74N Default", short_name: "AKD", categories: [ "preset" ], data: { "base_item" => base.bsg_id })

    get item_url(preset)

    assert_response :success
    assert_select "dt", text: "Base item"
    assert_select "a[href=?]", item_path(base), text: "AK-74N"
  ensure
    preset&.destroy
    base&.destroy
  end

  test "show links a weapon to its default preset" do
    preset = create_item("SCAR-L Default", short_name: "SCARD")
    weapon = create_item("SCAR-L", klass: Item::Weapon, short_name: "SCAR", data: { "caliber" => "Caliber556x45NATO", "default_preset" => preset.bsg_id })

    get item_url(weapon)

    assert_response :success
    assert_select "dt", text: "Default preset"
    assert_select "a[href=?]", item_path(preset), text: "SCAR-L Default"
  ensure
    weapon&.destroy
    preset&.destroy
  end

  test "show renders prerequisite chain with lvl + trader requirements in How to Unlock" do
    item = create_item("7.62x51mm M80")
    wet1, guide, cleaner = build_three_step_chain
    unlock_via_task(cleaner, item)

    get_ok(item_url(item))

    assert_chain_timeline
    assert_select "h2", text: /How to unlock/
  ensure
    destroy_unlock_fixtures(item, [ wet1, guide, cleaner ])
  end

  test "show renders inline chain under item_currency with task_unlock=true" do
    item = create_item("M80 Currency")
    wet1, _guide, cleaner = build_three_step_chain
    unlock_via_task(cleaner, item)

    item.item_currencies.create!(trader: "Peacekeeper", currency: "USD", min_trader_level: 4, task_unlock: true)

    get_ok(item_url(item))

    assert_chain_timeline
    # Badge in the row itself
    assert_select "span", text: /Task-gated/
  ensure
    destroy_unlock_fixtures(item, [ wet1, cleaner ])
  end

  test "show renders 'unlocking task not found' for task_currency when no OfferUnlock" do
    item = create_item("M80d", short_name: "M80d")
    item.item_currencies.create!(trader: "Peacekeeper", currency: "USD", min_trader_level: 4, task_unlock: true)

    get_ok(item_url(item))

    assert_select "p", text: /Task-gated trader offer/
    assert_select "p", text: /quest is not recorded/
  ensure
    item&.item_currencies&.destroy_all
    item&.destroy
  end

  private

  # A barter/craft unlock with one requirement row that consumes the item.
  # The timeline both unlock-path tests render: every node named, with the
  # per-node level and trader requirements.

  private

  def assert_chain_timeline
    assert_select ".timeline-node", minimum: 1
    assert_select ".timeline-node", text: /Wet Job Part 1/
    assert_select ".timeline-node", text: /The Guide/
    assert_select ".timeline-node", text: /The Cleaner/
    # Each node names the trader that gives the quest.
    assert_select ".timeline-node", text: /Mechanic/
    assert_select ".timeline-node .font-data", minimum: 1, text: /lvl 14/
    assert_select ".timeline-node .font-data", text: /LL4/
    assert_select ".timeline-node .font-data", text: /Peacekeeper LL3/
  end

  # Wet Job 1 -> The Guide -> The Cleaner, the chain both unlock-path tests
  # render. Returns the three tasks.
  def build_three_step_chain
    wet1 = create_chain_task("Wet Job 1", "wet-job-part-1", given_by: "Mechanic", player_level: 14)
    guide = create_chain_task("The Guide", "the-guide",
                              trader_level: [ { "trader_name" => "", "trader_level" => "4" } ], previous: wet1)
    cleaner = create_chain_task("The Cleaner", "the-cleaner",
                                trader_level: [ { "trader_name" => "peacekeeper", "trader_level" => "3" } ], previous: guide)
    [ wet1, guide, cleaner ]
  end
end
