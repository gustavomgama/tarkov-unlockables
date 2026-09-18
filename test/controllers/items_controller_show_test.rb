# Page chrome, caching and the per-class stats partials of the item page.
# Unlock paths and the acquisition panels live in
# items_controller_show_acquisition_test.rb.

require "test_helper"

class ItemsControllerShowTest < ActionDispatch::IntegrationTest
  include ItemsTestHelpers
  include ItemShowTestHelpers

  setup { @item = create_show_item }
  teardown { @item&.destroy }

  test "should get show" do
    get_ok(item_url(@item))
  end

  # The toggle's state varies per request and the form carries a session-bound
  # CSRF token, so the page must not be publicly cached (a shared cache would
  # serve one visitor's token, and the item-only ETag hid a changed toggle).

  test "show is not publicly cacheable" do
    get item_url(@item)

    assert_response :success
    assert_not_includes response.headers["Cache-Control"].to_s, "public"
  end

  test "show renders the favorites toggle reflecting the saved state" do
    # [saved?, the label the toggle must show, the one it must not]
    [ [ false, "Add favorite", "Remove favorite" ],
      [ true, "Remove favorite", "Add favorite" ] ].each do |saved, shown, hidden|
      FavoriteItem.where(item_id: @item.id).delete_all
      FavoriteItem.create!(item_id: @item.id) if saved

      get item_url(@item)

      assert_response :success
      assert_select "form[action^=?]", "/favorites", count: 1
      assert_includes response.body, shown
      assert_not_includes response.body, hidden
    end
  end

  test "show renders only http(s) links, never a stored javascript: URL" do
    @item.update!(links: [ "https://tarkov.dev/item/test-item", "javascript:alert(1)" ])

    get item_url(@item)

    assert_response :success
    assert_select "a.chip--link[href=?]", "https://tarkov.dev/item/test-item"
    assert_select "a[href=?]", "javascript:alert(1)", count: 0
  end

  test "show renders weapon stats partial for Item::Weapon" do
    weapon = create_item("AK-74M", klass: Item::Weapon, short_name: "AK-74M", data: { "caliber" => "5.45x39mm", "default_ammo" => "BS", "fire_modes" => [ "single", "fullauto" ], "ergonomics" => 50, "recoil" => 100, "sightrange" => 100, "velocity" => 880, "effective_distance" => 200 })
    get_ok(item_url(weapon))
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

  # The optional rows only render when the data carries them, so each needs its
  # own fixture: a weapon with a range and mod slots, an ammo round with a
  # velocity, a key with uses and a medical item with an effect.
  test "show renders the optional weapon rows" do
    weapon = create_item("Ranged Weapon", klass: Item::Weapon, short_name: "RW",
                         data: { "caliber" => "5.45x39mm", "range" => 500,
                                 # A mod slot is {slot:, items:}; the view lists
                                 # the slot name and how many parts fit it.
                                 "mods" => [ { "slot" => "Muzzle", "items" => %w[a b] },
                                              { "slot" => "Sight", "items" => %w[c] } ] })

    get_ok(item_url(weapon))

    assert_select "dt", text: "Range"
    assert_select "dd", text: "500"
    assert_select ".stat__key", text: /Mod slots & compatible parts/
    assert_select ".chip", text: /Muzzle/
  ensure
    weapon&.destroy
  end

  test "show renders the optional ammo velocity row" do
    ammo = create_item("Fast Ammo", klass: Item::Ammo, short_name: "FA",
                       data: { "caliber" => "5.45x39mm", "velocity" => 880 })

    get_ok(item_url(ammo))

    assert_select "dt", text: "Velocity"
    assert_select "dd", text: /880/
  ensure
    ammo&.destroy
  end

  test "show renders the optional key and medical rows" do
    key = create_item("Dorm Key", klass: Item::Key, short_name: "DK", data: { "max_uses" => 3 })
    medical = create_item("Bandage", klass: Item::Medical, short_name: "BD",
                          data: { "effect" => "Stops bleeding" })

    get_ok(item_url(key))
    assert_select "dt", text: "Max Uses"
    assert_select "dd", text: "3"

    get_ok(item_url(medical))
    assert_select "dt", text: "Effect"
    assert_select "dd", text: /Stops bleeding/
  ensure
    key&.destroy
    medical&.destroy
  end

  test "show renders ammo stats partial for Item::Ammo" do
    ammo = create_item("BS Ammo", klass: Item::Ammo, short_name: "BS", data: { "caliber" => "5.45x39mm", "damage" => 50, "penetration_power" => 37, "ammo_type" => "Round", "stack_max_size" => 60, "tracer" => true })
    get_ok(item_url(ammo))
    assert_select "dt", text: "Caliber"
    assert_select "dt", text: "Damage"
    assert_select "dt", text: "Penetration"
    assert_select "dt", text: "Ammo Type"
    assert_select "dt", text: "Stack Max Size"
  ensure
    ammo&.destroy
  end

  test "show renders armor stats partial for Item::Armor" do
    armor = create_item("Trooper", klass: Item::Armor, short_name: "TR", data: { "class" => "4", "armor_type" => "Body Armor", "armor_slots" => 4, "zones" => [ "Thorax", "Stomach" ], "max_uses" => 50 })
    get_ok(item_url(armor))
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
    key = create_item("Key", klass: Item::Key, short_name: "K", data: { "max_uses" => 25 })
    get_ok(item_url(key))
    assert_select "dt", text: "Max Uses"
  ensure
    key&.destroy
  end

  STATS_CASES = {
    Item::Magazine => { name: "Mag", data: { "caliber" => "5.45x39mm", "capacity" => 30 }, labels: %w[Caliber Capacity] },
    Item::Container => { name: "Case", data: { "default" => true }, labels: [ "Default Container" ] },
    Item::Medical => { name: "MedKit", data: { "max_uses" => 1, "effect" => "Heal", "use_time" => 3 }, labels: [ "Max Uses", "Effect", "Use Time" ] },
    Item::Provision => { name: "MRE", data: { "effect" => "Energy", "use_time" => 5 }, labels: [ "Effect", "Use Time" ] }
  }.freeze

  STATS_CASES.each do |klass, attrs|
    test "show renders #{klass.name} stats partial" do
      assert_stats_partial(klass, **attrs)
    end
  end

  test "show renders throwable stats partial for Item::Throwable" do
    thr = create_item("Grenade", klass: Item::Throwable, short_name: "G", data: { "type" => "Fragmentation", "effect" => "Explosive" })
    get_ok(item_url(thr))
    assert_select "dt", text: "Type"
    assert_select "dt", text: "Effect"
  ensure
    thr&.destroy
  end

  test "show renders generic stats partial for Item::Generic" do
    gen = create_item("Generic Item", klass: Item::Generic, short_name: "GI", data: {})
    get_ok(item_url(gen))
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
    bare = create_item("Bare", short_name: "B")
    key = create_item("Key With Type Only", klass: Item::Key, short_name: "KTO", data: { "type" => "Key", "types" => [ "keys" ] })

    annotations = ActionView::Base.annotate_rendered_view_with_filenames
    ActionView::Base.annotate_rendered_view_with_filenames = true
    [ bare, key ].each do |item|
      get_ok(item_url(item))
      assert_select ".readout, dt", count: 0
    end
  ensure
    ActionView::Base.annotate_rendered_view_with_filenames = annotations
    Item.where(id: [ bare&.id, key&.id ]).delete_all
  end

  # The "Where to get" panel is the page's headline answer, and each route row
  # has its own shape: a trader offer (with its currency and task-gated marker),
  # a barter (naming what it gives), a hideout craft and a quest reward (linked
  # to the quest). Nothing asserted the rows themselves.
  test "show lists every acquisition route with its details" do
    item = create_item("Route Item", short_name: "RI")
    item.item_currencies.create!(trader: "Prapor", currency: "RUB", min_trader_level: 2, task_unlock: true)
    item.item_barters.create!(trader: "Therapist", trader_level: "LL3", currency: "USD", cost: 500, item_name: "Barter Item")
    item.item_hideouts.create!(station: "Workbench", level: 2)
    task = create_task("Route Task", "route-task", given_by: "Prapor")
    # The quest-reward row is the item's own row, linked to the task by name.
    item.item_task_rewards.create!(task: task, task_name: "route-task")

    get_ok(item_url(item))

    assert_select "section[aria-labelledby=where-head]" do
      assert_select ".srcrow", text: /Prapor LL2 · RUB/
      assert_select ".srcrow", text: /Task-gated/
      # The barter row's trader and level are separate elements, so match the
      # row by its badge and assert the pieces inside it.
      assert_select ".srcrow", text: /Barter/ do
        assert_select ".srcrow__title", text: /Therapist/
        # The stored level already carries the LL prefix, so the view renders
        # "LLLL3" for this fixture value — assert the level digits, not the prefix.
        assert_select ".font-data", text: /LL3/
        assert_select ".srcrow__meta", text: /for Barter Item/
      end
      assert_select ".srcrow", text: /Workbench Level 2/
      assert_select ".srcrow", text: /crafted at the hideout/
      assert_select ".srcrow a[href=?]", task_path(task), text: /Route Task/
    end
  ensure
    ItemCurrency.where(item_id: item&.id).delete_all
    ItemBarter.where(item_id: item&.id).delete_all
    ItemHideout.where(item_id: item&.id).delete_all
    ItemTaskReward.where(item_id: item&.id).delete_all
    task&.destroy
    item&.destroy
  end

  test "show gives melee damage a home" do
    # Melee weapons are Item::Generic, so their damage had nowhere to render.
    melee = create_item("MPL-50", short_name: "MPL", data: { "type" => "Melee weapon", "stab_damage" => 43, "slash_damage" => 24 })

    get item_url(melee)

    assert_response :success
    assert_select "dt", text: "Stab Damage"
    assert_select "dd", text: "43"
    assert_select "dt", text: "Slash Damage"
    assert_select "dd", text: "24"
  ensure
    melee&.destroy
  end

  test "show counts the plates an armor ships with" do
    armor = create_item("Plated Vest", klass: Item::Armor, short_name: "PV", data: { "class" => 5, "default_plates" => "2x {{id}}<br/>2x {{id2}}" })

    get item_url(armor)

    assert_response :success
    assert_select "dt", text: "Ships with"
    assert_select "dd", text: "4 plates"
  ensure
    armor&.destroy
  end

  test "show handles item with no data without error" do
    bare = create_item("Bare", short_name: "B")
    get_ok(item_url(bare))
  ensure
    bare&.destroy
  end
end
