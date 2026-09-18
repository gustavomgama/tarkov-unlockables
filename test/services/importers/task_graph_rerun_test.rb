# frozen_string_literal: true

require "test_helper"

# Re-running the importer and the malformed source rows it has to absorb. The
# core import assertions live in task_graph_test.rb.
class Importers::TaskGraphRerunTest < ActiveSupport::TestCase
  include ImportersTaskGraphHelpers

  setup { write_shared_fixture }
  teardown { remove_shared_fixture }

  test "is idempotent when run twice" do
    run_import!
    counts = snapshot_counts
    run_import!

    assert_equal counts, snapshot_counts, "counts must be stable across runs"
  end

  test "updates existing tasks on re-run rather than duplicating" do
    run_import!
    before = Task.where(bsg_id: %w[tg_task_a tg_task_b]).count
    run_import!

    assert_equal 2, before
    assert_equal before, Task.where(bsg_id: %w[tg_task_a tg_task_b]).count
  end

  test "recomputes dependent rows on re-run (no duplicates)" do
    counts = lambda do
      a = imported_task_a.reload
      { leads_tos: a.leads_tos.count, rewards: a.rewards.count,
        loose_items: finish_reward_for(a).loose_items.count }
    end

    run_import!
    before = counts.call
    run_import!

    assert_equal before, counts.call
  end

  # 82 entries in the real source name an item without a bsg_id. Those have to
  # land as a name-only row instead of raising on a blank lookup.
  test "a reward entry with no item bsg keeps the name only" do
    write_fixture([
      {
        "bsg_id" => "tg_blank_item", "full_name" => "Blank Item", "name" => "blank-item",
        "given_by" => "Prapor", "start_rewards" => [],
        "finish_rewards" => [
          { "loose_items" => [ { "item_id" => nil, "item_name" => "Nameless Ref", "count" => "1" } ] }
        ]
      }
    ])

    run_import!

    row = Task.find_by(bsg_id: "tg_blank_item").rewards.first.loose_items.first
    assert_equal "Nameless Ref", row.item_name
    assert_nil row.item_id
  end

  # The source carries no null reward entries today; the guard exists so a
  # schema change cannot take the whole import down.
  test "a null reward entry is skipped" do
    write_fixture([
      {
        "bsg_id" => "tg_null_reward", "full_name" => "Null Reward", "name" => "null-reward",
        "given_by" => "Prapor", "start_rewards" => [], "finish_rewards" => [ nil ]
      }
    ])

    run_import!

    assert_equal 0, Task.find_by(bsg_id: "tg_null_reward").rewards.count
  end

  # 52 Ref/Arena quests in the real source carry no bsg_id and no name slug.
  # Keying the upsert on the blank bsg_id collapsed them into a single row — 51
  # quests were silently lost (468 tasks imported instead of 519) — and the
  # duplicate blank names collided in the chain map, which indexes by name.
  test "tasks without a bsg_id or name are kept apart" do
    write_fixture([
      { "bsg_id" => "", "full_name" => "Arena One", "name" => "", "given_by" => "ref",
        "start_rewards" => [], "finish_rewards" => [] },
      { "bsg_id" => "", "full_name" => "Arena Two", "name" => "", "given_by" => "ref",
        "start_rewards" => [], "finish_rewards" => [] }
    ])

    run_import!

    arenas = Task.where(full_name: [ "Arena One", "Arena Two" ]).order(:name)

    assert_equal 2, arenas.count, "both blank-bsg_id quests must survive"
    assert_equal %w[arena-one arena-two], arenas.pluck(:name)
    assert arenas.all? { |task| task.bsg_id.nil? }, "the id column must stay honest (nil, not '')"
  end

  # 502 references leave task_id blank; 408 of them name the task's slug instead.
  # Resolving them by `bsg_id: ""` used to attach the reference to whichever
  # blank-id row happened to exist.
  test "a reference with only a task_name links by slug" do
    write_fixture([
      link_fixture("tg_link_target", "Link Target", "link-target"),
      link_fixture("tg_link_source", "Link Source", "link-source",
                   leads_to: [ { "task_id" => "", "task_name" => "link-target" } ])
    ])

    run_import!

    link = Task.find_by(bsg_id: "tg_link_source").leads_tos.first

    assert_equal Task.find_by(bsg_id: "tg_link_target").id, link.follow_up_task_id
  end

  # 48 rows in the real source name neither a task nor a bsg_id. They would
  # render as an empty "Leads to" chip and inflate the row's lead count, so the
  # importer drops them.
  test "a reference with neither a link nor a name creates no row" do
    write_fixture([
      link_fixture("tg_blank_ref", "Blank Ref", "blank-ref",
                   leads_to: [ { "task_id" => "", "task_name" => "" } ])
    ])

    run_import!

    task = Task.find_by(bsg_id: "tg_blank_ref")
    assert_equal 0, task.leads_tos.count
    assert_equal 0, task.leads_tos_count
  end

  test "a reference to an unknown task bsg_id stays unlinked" do
    write_fixture([
      link_fixture("tg_unknown_ref", "Unknown Ref", "unknown-ref",
                   leads_to: [ { "task_id" => "not-a-task", "task_name" => "ghost" } ])
    ])

    run_import!

    link = Task.find_by(bsg_id: "tg_unknown_ref").leads_tos.first

    assert_nil link.follow_up_task_id
    assert_equal "ghost", link.follow_up_task_name
  end
end
