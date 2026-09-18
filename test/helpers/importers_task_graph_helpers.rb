# frozen_string_literal: true

# Shared fixtures for the task-graph importer tests, which are split between
# task_graph_test.rb (the core import) and task_graph_rerun_test.rb (re-runs and
# malformed source rows).
module ImportersTaskGraphHelpers
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

  # Rows the fixture defines; fetched by their stable bsg_ids.
  def imported_task_a
    Task.find_by(bsg_id: "tg_task_a")
  end

  def imported_item
    Item.find_by(bsg_id: "tg_item_present")
  end

  def finish_reward_for(task)
    task.rewards.find_by(reward_type: "finish_rewards")
  end

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
            "trader_level" => [ { "trader_name" => "therapist", "trader_level" => "2" } ],
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

  # The core fixture: one identified item plus a two-task graph. Both files need
  # the same rows, so it is written from each test's setup.
  def write_shared_fixture
    # Only one Item exists in DB (tg_item_present); tg_item_absent has no Item row.
    Item.create!(bsg_id: "tg_item_present", slug: "present", full_name: "Present Item",
                 short_name: "PI", categories: [ "general" ], data: {})
    write_fixture(fixture_tasks)
  end

  def remove_shared_fixture
    FileUtils.rm_f(fixture_path)
  end

  # A minimal task row for the link-resolution tests: no rewards, optional
  # leads_to entries.
  def link_fixture(bsg_id, full_name, name, leads_to: [])
    { "bsg_id" => bsg_id, "full_name" => full_name, "name" => name, "given_by" => "Prapor",
      "leads_to" => leads_to, "start_rewards" => [], "finish_rewards" => [] }
  end

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
