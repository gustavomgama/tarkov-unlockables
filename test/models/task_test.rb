require "test_helper"

# == Schema Information
#
# Table name: tasks
#
#  id                   :bigint           not null, primary key
#  bsg_id               :string
#  full_name            :string
#  name                 :string
#  wiki_link            :string
#  given_by             :string
#  kappa_required       :boolean
#  lightkeeper_required :boolean
#  leads_tos_count      :integer          default(0), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  search_text          :string           default(""), not null
#  map_id               :string
#  map_name             :string
#  experience           :integer
#  faction              :string
#  needed_keys          :jsonb            not null
#
# Indexes
#
#  index_tasks_on_full_name         (full_name)
#  index_tasks_on_given_by          (given_by)
#  index_tasks_on_map_name          (map_name)
#  index_tasks_on_name              (name)
#  index_tasks_on_search_text_trgm  (search_text) USING gin
#
class TaskTest < ActiveSupport::TestCase
  PEACEKEEPER_LL3 = [ { "trader_name" => "peacekeeper", "trader_level" => "3" } ].freeze
  UNNAMED_TRADER_LL4 = [ { "trader_name" => "", "trader_level" => "4" } ].freeze
  WET_JOBS = (1..6).map { |n| [ "Wet Job #{n}", "wet-job-part-#{n}" ] }.freeze

  test "has task graph associations" do
    task = create_task("Debut", "debut", given_by: "Prapor")

    {
      rewards: { reward_type: "Item" },
      leads_tos: { follow_up_task_name: "Shootout" },
      requirements: { player_level: 5 },
      item_task_rewards: { item: create_item("Item"), task_name: "Debut" }
    }.each do |association, attrs|
      task.public_send(association).create!(attrs)

      assert_equal 1, task.public_send(association).count
    end
  end

  test "leads_tos_count counter cache increments" do
    task = create_task("Counter", "counter")
    assert_equal 0, task.leads_tos_count

    task.leads_tos.create!(follow_up_task_name: "Next")
    assert_equal 1, task.reload.leads_tos_count
  end

  test "prerequisite_chain walks previous tasks" do
    first = create_task("First", "first", given_by: "Prapor")
    second = create_task("Second", "second", given_by: "Prapor")
    link_prerequisite(second, first, player_level: 10)

    chain = second.prerequisite_chain
    assert_equal 2, chain.length
    assert_equal "second", chain.first[:name]
    assert_equal "first", chain.last[:name]
  end

  test "prerequisite_chain marks an alternative prerequisite" do
    first = Task.create!(bsg_id: "alt1-#{SecureRandom.hex(4)}", full_name: "Alt First", name: "alt-first", given_by: "Prapor")
    second = Task.create!(bsg_id: "alt2-#{SecureRandom.hex(4)}", full_name: "Alt Second", name: "alt-second", given_by: "Prapor")

    req = second.requirements.create!(player_level: 0)
    req.previous_tasks.create!(task: first, task_name: "alt-first", alternative: true)

    chain = second.prerequisite_chain
    refute chain.first[:alternative]
    assert chain.last[:alternative]
  end

  # --- Task 11: chain node carries requirements (player_level + trader_requirements) ---

  test "prerequisite_chain node carries player_level + trader_requirements" do
    first = create_task("First", "first", given_by: "Prapor")
    second = create_task("Second", "second", given_by: "Therapist")
    link_prerequisite(second, first, player_level: 14, trader_level: PEACEKEEPER_LL3)

    chain = second.prerequisite_chain
    assert_requirement chain.first, player_level: 14, trader_level: PEACEKEEPER_LL3
    assert_requirement chain.last, player_level: 0, trader_level: []
  end

  test "prerequisite_chain full chain length 8 (wet-job 1..6 -> the-guide -> the-cleaner)" do
    # Build the chain that mirrors the source (Task 11 example: M80 unlock path)
    wet = WET_JOBS.map { |full_name, name| create_task(full_name, name, given_by: "Mechanic") }
    guide = create_task("The Guide", "the-guide", given_by: "Peacekeeper")
    cleaner = create_task("The Cleaner", "the-cleaner", given_by: "Peacekeeper")

    wet.first.requirements.create!(player_level: 14, trader_level: [])
    wet.each_cons(2).with_index do |(prev, task), index|
      # wet-job-2..5 need level 14; wet-job-6 (the last link) is unlocked at 0.
      link_prerequisite(task, prev, player_level: index < 4 ? 14 : 0)
    end
    link_prerequisite(guide, wet.last, player_level: 0, trader_level: UNNAMED_TRADER_LL4)
    link_prerequisite(cleaner, guide, player_level: 0, trader_level: PEACEKEEPER_LL3)

    chain = cleaner.prerequisite_chain
    # The slug order is the whole chain, so it proves the length too.
    assert_equal %w[the-cleaner the-guide wet-job-part-6 wet-job-part-5 wet-job-part-4
                    wet-job-part-3 wet-job-part-2 wet-job-part-1],
                 chain.map { |n| n[:name] }

    # [chain index, player level, trader requirements]: -1 is the root (wet-job-1),
    # 1 is the-guide, 0 is the-cleaner.
    { -1 => [ 14, [] ], 1 => [ 0, UNNAMED_TRADER_LL4 ], 0 => [ 0, PEACEKEEPER_LL3 ] }.each do |index, (level, traders)|
      assert_requirement chain[index], player_level: level, trader_level: traders
    end
  end

  test "prerequisite_chain returns trader_requirements=[] for task with no requirement row" do
    task = create_task("No Req", "no-req", given_by: "Prapor")
    chain = task.prerequisite_chain
    assert_equal 1, chain.length
    assert_requirement chain.first, player_level: 0, trader_level: []
  end

  # Both cross-task reference columns (leads_tos.follow_up_task_id and
  # previous_tasks.task_id) carry a restrict FK and neither had an inverse
  # association on Task, so deleting a task that another task leads to, or that
  # another task requires as a prerequisite, raised a foreign-key violation —
  # the admin Delete action 500d for any task in the middle of the graph.
  test "destroying a task clears the other tasks' pointers to it" do
    referenced = create_task("Referenced Task")
    other = create_task("Other Task")
    other.leads_tos.create!(follow_up_task_name: referenced.name, follow_up_task: referenced)
    requirement = other.requirements.create!(player_level: 5)
    requirement.previous_tasks.create!(task: referenced, task_name: referenced.name)

    referenced.destroy!

    assert_nil LeadsTo.find_by(follow_up_task_name: referenced.name).follow_up_task_id
    assert_nil PreviousTask.find_by(task_name: referenced.name).task_id
  end

  # The admin Delete action runs on any task in the graph. Deleting every fixture
  # task at once proves each reference edge (own rows, cross-task pointers, and
  # rewards → unlocks → requirements/results → items) has a handler; a missing
  # one surfaces as a foreign-key violation here instead of a 500 in the admin.
  test "every fixture task can be destroyed with the graph attached" do
    Task.all.to_a.each(&:destroy!)

    assert_equal 0, Task.count
  end

  # A prerequisite row can outlive the task it names (a deleted task, a stale
  # import). The walk has to skip it rather than raise.
  test "prerequisite_chain skips a previous task that no longer exists" do
    task = create_task("Orphan Chain", "orphan-chain")
    requirement = task.requirements.create!(player_level: 5)
    requirement.previous_tasks.create!(task_name: "deleted-task")

    chain = task.prerequisite_chain

    assert_equal 1, chain.length
    assert_equal "orphan-chain", chain.first[:name]
  end

  # The importer resolves every reference with find_by/find_or_initialize_by on
  # bsg_id; the unique index is what makes that lookup both safe and fast, and
  # pins the one-task-per-bsg_id invariant.
  test "tasks.bsg_id is uniquely indexed" do
    index = ActiveRecord::Base.connection.indexes(:tasks).find { |i| i.columns == [ "bsg_id" ] }

    assert index&.unique, "tasks.bsg_id needs a unique index for the importer's lookups"
  end

  private

  # Creates `prev` as the single prerequisite of `task` and returns the new row.
  def link_prerequisite(task, prev, player_level:, trader_level: [])
    requirement = task.requirements.create!(player_level: player_level, trader_level: trader_level)
    requirement.previous_tasks.create!(task: prev, task_name: prev.name)
    requirement
  end

  def assert_requirement(node, player_level:, trader_level:)
    assert_equal player_level, node[:player_level]
    assert_equal trader_level, node[:trader_requirements]
  end
end
