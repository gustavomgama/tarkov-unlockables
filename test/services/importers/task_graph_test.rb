# frozen_string_literal: true

require "test_helper"

class Importers::TaskGraphTest < ActiveSupport::TestCase
  include ImportersTaskGraphHelpers

  setup { write_shared_fixture }
  teardown { remove_shared_fixture }
  # Walks the requirement/result nesting shared by barter and craft unlocks.
  # Returns [requirement, requirement_item, result_item].
  # Barter and craft unlocks share the same shape: one "<prefix>_requirements"
  # row (with one "<prefix>_requirement_items" row) and one "<prefix>_results"
  # row (with one "<prefix>_result_items" row). Asserts one of each and returns
  # [requirement, requirement_item, result_item].
  def unlock_rows(unlock, prefix)
    requirement = sole(unlock.public_send(:"#{prefix}_requirements"))
    requirement_item = sole(requirement.public_send(:"#{prefix}_requirement_items"))
    result = sole(unlock.public_send(:"#{prefix}_results"))
    [ requirement, requirement_item, sole(result.public_send(:"#{prefix}_result_items")) ]
  end

  def sole(relation)
    assert_equal 1, relation.size
    relation.first
  end

  # --- Fixtures ---------------------------------------------------------------

  # Two tasks: task_a leads to task_b. task_b requires task_a as previous task.
  # task_a has finish_rewards with loose_items (item_present + item_absent),
  # offer_unlocks with trader_level "LL3" (must be stripped to "3"),
  # barter_unlocks with req/result items + barter_requirements.trader_level "LL2",
  # and craft_unlocks with craft_requirements.trader_level "LL1".
  # --- Tests ------------------------------------------------------------------

  test "creates tasks with attributes" do
    run_import!

    a = imported_task_a
    assert_equal({ full_name: "Task Alpha", name: "task-alpha",
                   wiki_link: "https://example.com/task-alpha", given_by: "Prapor" },
                 a.attributes.symbolize_keys.slice(:full_name, :name, :wiki_link, :given_by))
    assert a.kappa_required
    refute a.lightkeeper_required

    assert_equal "Task Bravo", Task.find_by(bsg_id: "tg_task_b").full_name
  end

  test "creates leads_tos with FK resolved via bsg_id; NULL when absent" do
    run_import!

    links = imported_task_a.leads_tos.index_by(&:follow_up_task_name)
    assert_equal 2, links.size

    assert_equal Task.find_by(bsg_id: "tg_task_b").id, links["task-bravo"].follow_up_task_id
    assert_nil links["task-missing"].follow_up_task_id
  end

  test "creates requirements with player_level + previous_tasks (FK resolved)" do
    run_import!

    req = Task.find_by(bsg_id: "tg_task_b").requirements.first
    assert_equal 10, req.player_level

    # One row resolves to a real task, the other names a task that is absent.
    assert_equal({ "task-alpha" => imported_task_a.id, "task-ghost" => nil },
                 req.previous_tasks.index_by(&:task_name).transform_values(&:task_id))
  end

  # --- Task 11: trader_level jsonb populated from source ---

  test "imports trader_level from source on each requirement (task_graph)" do
    run_import!

    a = imported_task_a
    assert_equal [], a.requirements.first.trader_level

    b = Task.find_by(bsg_id: "tg_task_b")
    assert_equal [ { "trader_name" => "therapist", "trader_level" => "2" } ], b.requirements.first.trader_level
  end

  test "imports empty trader_name entry (e.g. the-guide LL4)" do
    # Inline fixture: a single task with a trader_level entry whose trader_name is blank.
    write_fixture([
      {
        "bsg_id" => "tg_task_guide",
        "full_name" => "The Guide",
        "name" => "the-guide",
        "wiki_link" => "",
        "given_by" => "Peacekeeper",
        "kappa_required" => "false",
        "lightkeeper_required" => "false",
        "leads_to" => [],
        "requirements" => [
          {
            "player_level" => "0",
            "trader_level" => [ { "trader_name" => "", "trader_level" => "4" } ],
            "previous_tasks" => []
          }
        ],
        "start_rewards" => [ { "loose_items" => [], "offer_unlocks" => [], "barter_unlocks" => [], "craft_unlocks" => [] } ],
        "finish_rewards" => [ { "loose_items" => [], "offer_unlocks" => [], "barter_unlocks" => [], "craft_unlocks" => [] } ]
      }
    ])
    run_import!

    guide = Task.find_by(bsg_id: "tg_task_guide")
    assert_equal [ { "trader_name" => "", "trader_level" => "4" } ], guide.requirements.first.trader_level
  end

  test "creates rewards (start_rewards + finish_rewards)" do
    run_import!

    a = imported_task_a
    assert_equal 2, a.rewards.size
    assert_equal [ "start_rewards", "finish_rewards" ].sort, a.rewards.pluck(:reward_type).sort

    b = Task.find_by(bsg_id: "tg_task_b")
    assert_equal 2, b.rewards.size
  end

  test "creates loose_items with item_id resolved; NULL when absent" do
    run_import!

    rows = finish_reward_for(imported_task_a).loose_items.index_by(&:item_name)

    assert_equal({ "Present Item" => [ imported_item.id, 3 ], "Absent Item" => [ nil, 1 ] },
                 rows.transform_values { |row| [ row.item_id, row.count ] })
  end

  test "offer_unlocks: trader_level strips LL (LL3 -> 3)" do
    run_import!

    offer = finish_reward_for(imported_task_a).offer_unlocks.first

    assert_equal({ item_id: imported_item.id, trader_name: "Therapist", trader_level: "3" },
                 offer.attributes.symbolize_keys.slice(:item_id, :trader_name, :trader_level))
  end

  # Barter and craft unlocks share the same nesting; the two cases differ only
  # in the unlock's own columns and the expected requirement/result values.
  UNLOCK_CASES = {
    barter: { trader: "Skier", level: "2", count: 2, result_item_id: nil },
    craft: { trader: "Mechanic", level: "1", count: 4, result_item_id: :item }
  }.freeze

  UNLOCK_CASES.each do |prefix, expected|
    test "#{prefix}_unlocks: nested trader_level strips LL; req/result items resolved" do
      run_import!

      unlock = finish_reward_for(imported_task_a).public_send("#{prefix}_unlocks").first
      item = imported_item

      req, requirement_item, result_item = unlock_rows(unlock, prefix)
      assert_equal expected[:trader], req.trader_name
      assert_equal expected[:level], req.trader_level
      assert_equal item.id, requirement_item.item_id
      assert_equal expected[:count], requirement_item.count
      if expected[:result_item_id] == :item
        assert_equal item.id, result_item.item_id
      else
        assert_nil result_item.item_id
      end
    end
  end
end
