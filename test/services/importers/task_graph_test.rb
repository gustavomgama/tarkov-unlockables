# frozen_string_literal: true

require "test_helper"

class Importers::TaskGraphTest < ActiveSupport::TestCase
  def fixture_path
    @fixture_path ||= Rails.root.join("tmp/importers_task_graph_test_fixture.json")
  end

  def write_fixture(tasks)
    FileUtils.mkdir_p(fixture_path.dirname)
    File.write(fixture_path, JSON.generate(tasks))
  end

  def run_import!
    Importers::TaskGraph.import!(source: fixture_path)
  end

  # --- Fixtures ---------------------------------------------------------------

  # Two tasks: task_a leads to task_b. task_b requires task_a as previous task.
  # task_a has finish_rewards with loose_items (item_present + item_absent),
  # offer_unlocks with trader_level "LL3" (must be stripped to "3"),
  # barter_unlocks with req/result items + barter_requirements.trader_level "LL2",
  # and craft_unlocks with craft_requirements.trader_level "LL1".
  def fixture_tasks
    [
      {
        "bsg_id" => "tg_task_a",
        "full_name" => "Task Alpha",
        "name" => "task-alpha",
        "wiki_link" => "https://example.com/task-alpha",
        "given_by" => "Prapor",
        "kappa_required" => "true",
        "lightkeeper_required" => "false",
        "leads_to" => [
          { "task_id" => "tg_task_b", "task_name" => "task-bravo" },
          { "task_id" => "",         "task_name" => "task-missing" }
        ],
        "requirements" => [
          {
            "player_level" => "5",
            "trader_level" => [],
            "previous_tasks" => []
          }
        ],
        "start_rewards" => [ { "loose_items" => [], "offer_unlocks" => [], "barter_unlocks" => [], "craft_unlocks" => [] } ],
        "finish_rewards" => [
          {
            "loose_items" => [
              { "item_id" => "tg_item_present", "item_name" => "Present Item", "count" => "3" },
              { "item_id" => "tg_item_absent",  "item_name" => "Absent Item",  "count" => "1" }
            ],
            "offer_unlocks" => [
              { "item_id" => "tg_item_present", "item_name" => "Present Item", "trader_name" => "Therapist", "trader_level" => "LL3" }
            ],
            "barter_unlocks" => [
              {
                "requirements" => [
                  {
                    "items" => [
                      { "item_id" => "tg_item_present", "item_name" => "Present Item", "count" => "2" }
                    ],
                    "trader_name" => "Skier",
                    "trader_level" => "LL2"
                  }
                ],
                "result" => [
                  {
                    "items" => [
                      { "item_id" => "tg_item_absent", "item_name" => "Absent Item" }
                    ]
                  }
                ]
              }
            ],
            "craft_unlocks" => [
              {
                "item_id" => "tg_item_present",
                "item_name" => "Present Item",
                "hideout_station" => "Workbench",
                "station_level" => "2",
                "requirements" => [
                  {
                    "items" => [
                      { "id" => "tg_item_present", "name" => "Present Item", "quantity" => "4" }
                    ],
                    "trader_name" => "Mechanic",
                    "trader_level" => "LL1"
                  }
                ],
                "result" => [
                  {
                    "items" => [
                      { "id" => "tg_item_present", "name" => "Present Item" }
                    ]
                  }
                ]
              }
            ]
          }
        ]
      },
      {
        "bsg_id" => "tg_task_b",
        "full_name" => "Task Bravo",
        "name" => "task-bravo",
        "wiki_link" => "https://example.com/task-bravo",
        "given_by" => "Therapist",
        "kappa_required" => "false",
        "lightkeeper_required" => "false",
        "leads_to" => [],
        "requirements" => [
          {
            "player_level" => "10",
            "trader_level" => [],
            "previous_tasks" => [
              { "task_id" => "tg_task_a", "task_name" => "task-alpha" },
              { "task_id" => "",          "task_name" => "task-ghost" }
            ]
          }
        ],
        "start_rewards" => [ { "loose_items" => [], "offer_unlocks" => [], "barter_unlocks" => [], "craft_unlocks" => [] } ],
        "finish_rewards" => [
          {
            "loose_items" => [],
            "offer_unlocks" => [],
            "barter_unlocks" => [],
            "craft_unlocks" => []
          }
        ]
      }
    ]
  end

  setup do
    # Only one Item exists in DB (tg_item_present); tg_item_absent has no Item row.
    Item.create!(bsg_id: "tg_item_present", slug: "present", full_name: "Present Item",
                 short_name: "PI", categories: [ "general" ], data: {})
    write_fixture(fixture_tasks)
  end

  teardown do
    FileUtils.rm_f(fixture_path)
  end

  # --- Tests ------------------------------------------------------------------

  test "creates tasks with attributes" do
    run_import!

    a = Task.find_by(bsg_id: "tg_task_a")
    assert_equal "Task Alpha", a.full_name
    assert_equal "task-alpha", a.name
    assert_equal "https://example.com/task-alpha", a.wiki_link
    assert_equal "Prapor", a.given_by
    assert_equal true, a.kappa_required
    assert_equal false, a.lightkeeper_required

    b = Task.find_by(bsg_id: "tg_task_b")
    assert_equal "Task Bravo", b.full_name
  end

  test "creates leads_tos with FK resolved via bsg_id; NULL when absent" do
    run_import!

    a = Task.find_by(bsg_id: "tg_task_a")
    b = Task.find_by(bsg_id: "tg_task_b")

    leads_tos = a.leads_tos.order(:id)
    assert_equal 2, leads_tos.size

    real_lt = leads_tos.find { |lt| lt.follow_up_task_name == "task-bravo" }
    assert_equal b.id, real_lt.follow_up_task_id

    missing_lt = leads_tos.find { |lt| lt.follow_up_task_name == "task-missing" }
    assert_nil missing_lt.follow_up_task_id
  end

  test "creates requirements with player_level + previous_tasks (FK resolved)" do
    run_import!

    b = Task.find_by(bsg_id: "tg_task_b")
    assert_equal 1, b.requirements.size
    req = b.requirements.first
    assert_equal 10, req.player_level

    a = Task.find_by(bsg_id: "tg_task_a")
    pts = req.previous_tasks.order(:id)
    assert_equal 2, pts.size

    real_pt = pts.find { |pt| pt.task_name == "task-alpha" }
    assert_equal a.id, real_pt.task_id

    missing_pt = pts.find { |pt| pt.task_name == "task-ghost" }
    assert_nil missing_pt.task_id
  end

  test "creates rewards (start_rewards + finish_rewards)" do
    run_import!

    a = Task.find_by(bsg_id: "tg_task_a")
    assert_equal 2, a.rewards.size
    assert_equal [ "start_rewards", "finish_rewards" ].sort, a.rewards.pluck(:reward_type).sort

    b = Task.find_by(bsg_id: "tg_task_b")
    assert_equal 2, b.rewards.size
  end

  test "creates loose_items with item_id resolved; NULL when absent" do
    run_import!

    a = Task.find_by(bsg_id: "tg_task_a")
    finish_reward = a.rewards.find_by(reward_type: "finish_rewards")
    loose_items = finish_reward.loose_items.order(:id)
    assert_equal 2, loose_items.size

    present = loose_items.find { |li| li.item_name == "Present Item" }
    item = Item.find_by(bsg_id: "tg_item_present")
    assert_equal item.id, present.item_id
    assert_equal 3, present.count

    absent = loose_items.find { |li| li.item_name == "Absent Item" }
    assert_nil absent.item_id
  end

  test "offer_unlocks: trader_level strips LL (LL3 -> 3)" do
    run_import!

    a = Task.find_by(bsg_id: "tg_task_a")
    finish_reward = a.rewards.find_by(reward_type: "finish_rewards")
    offer = finish_reward.offer_unlocks.first
    item = Item.find_by(bsg_id: "tg_item_present")

    assert_equal item.id, offer.item_id
    assert_equal "Therapist", offer.trader_name
    assert_equal "3", offer.trader_level
  end

  test "barter_unlocks: nested barter_requirements.trader_level strips LL; req/result items resolved" do
    run_import!

    a = Task.find_by(bsg_id: "tg_task_a")
    finish_reward = a.rewards.find_by(reward_type: "finish_rewards")
    bu = finish_reward.barter_unlocks.first
    item = Item.find_by(bsg_id: "tg_item_present")

    # barter_unlock.item_id is the first result item (here: absent → nil)
    assert_nil bu.item_id
    assert_equal "Absent Item", bu.item_name

    assert_equal 1, bu.barter_requirements.size
    req = bu.barter_requirements.first
    assert_equal "Skier", req.trader_name
    assert_equal "2", req.trader_level

    assert_equal 1, req.barter_requirement_items.size
    bri = req.barter_requirement_items.first
    assert_equal item.id, bri.item_id
    assert_equal 2, bri.count

    assert_equal 1, bu.barter_results.size
    res = bu.barter_results.first
    assert_equal 1, res.barter_result_items.size
    assert_nil res.barter_result_items.first.item_id # absent
  end

  test "craft_unlocks: nested craft_requirements.trader_level strips LL; req/result items resolved" do
    run_import!

    a = Task.find_by(bsg_id: "tg_task_a")
    finish_reward = a.rewards.find_by(reward_type: "finish_rewards")
    cu = finish_reward.craft_unlocks.first
    item = Item.find_by(bsg_id: "tg_item_present")

    assert_equal item.id, cu.item_id
    assert_equal "Workbench", cu.hideout_station
    assert_equal 2, cu.station_level

    assert_equal 1, cu.craft_requirements.size
    req = cu.craft_requirements.first
    assert_equal "Mechanic", req.trader_name
    assert_equal "1", req.trader_level

    assert_equal 1, req.craft_requirement_items.size
    cri = req.craft_requirement_items.first
    assert_equal item.id, cri.item_id
    assert_equal 4, cri.count

    assert_equal 1, cu.craft_results.size
    res = cu.craft_results.first
    assert_equal 1, res.craft_result_items.size
    assert_equal item.id, res.craft_result_items.first.item_id
  end

  test "is idempotent when run twice" do
    run_import!
    counts = snapshot_counts
    run_import!

    assert_equal counts, snapshot_counts, "counts must be stable across runs"
  end

  test "updates existing tasks on re-run rather than duplicating" do
    run_import!
    assert_equal 2, Task.where(bsg_id: %w[tg_task_a tg_task_b]).count
    run_import!
    assert_equal 2, Task.where(bsg_id: %w[tg_task_a tg_task_b]).count
  end

  test "recomputes dependent rows on re-run (no duplicates)" do
    run_import!
    a = Task.find_by(bsg_id: "tg_task_a")
    initial_leads_tos = a.leads_tos.count
    initial_rewards   = a.rewards.count
    initial_requirements = a.rewards.find_by(reward_type: "finish_rewards").loose_items.count
    run_import!

    a.reload
    assert_equal initial_leads_tos, a.leads_tos.count
    assert_equal initial_rewards, a.rewards.count
    assert_equal initial_requirements, a.rewards.find_by(reward_type: "finish_rewards").loose_items.count
  end

  private

  def snapshot_counts
    {
      tasks: Task.count,
      leads_tos: LeadsTo.count,
      requirements: Requirement.count,
      previous_tasks: PreviousTask.count,
      rewards: Reward.count,
      loose_items: LooseItem.count,
      offer_unlocks: OfferUnlock.count,
      barter_unlocks: BarterUnlock.count,
      barter_requirements: BarterRequirement.count,
      barter_requirement_items: BarterRequirementItem.count,
      barter_results: BarterResult.count,
      barter_result_items: BarterResultItem.count,
      craft_unlocks: CraftUnlock.count,
      craft_requirements: CraftRequirement.count,
      craft_requirement_items: CraftRequirementItem.count,
      craft_results: CraftResult.count,
      craft_result_items: CraftResultItem.count
    }
  end
end
