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
#
class TaskTest < ActiveSupport::TestCase
  test "has task graph associations" do
    task = Task.create!(bsg_id: "t-#{SecureRandom.hex(4)}", full_name: "Debut", name: "debut", given_by: "Prapor")

    task.rewards.create!(reward_type: "Item")
    task.leads_tos.create!(follow_up_task_name: "Shootout")
    task.requirements.create!(player_level: 5)
    task.item_task_rewards.create!(item: Item.create!(bsg_id: "i-#{SecureRandom.hex(4)}", full_name: "Item", short_name: "I"), task_name: "Debut")

    assert_equal 1, task.rewards.count
    assert_equal 1, task.leads_tos.count
    assert_equal 1, task.requirements.count
    assert_equal 1, task.item_task_rewards.count
  end

  test "leads_tos_count counter cache increments" do
    task = Task.create!(bsg_id: "cc-#{SecureRandom.hex(4)}", full_name: "Counter", name: "counter")
    assert_equal 0, task.leads_tos_count

    task.leads_tos.create!(follow_up_task_name: "Next")
    assert_equal 1, task.reload.leads_tos_count
  end

  test "prerequisite_chain walks previous tasks" do
    first = Task.create!(bsg_id: "p1-#{SecureRandom.hex(4)}", full_name: "First", name: "first", given_by: "Prapor")
    second = Task.create!(bsg_id: "p2-#{SecureRandom.hex(4)}", full_name: "Second", name: "second", given_by: "Prapor")

    req = second.requirements.create!(player_level: 10)
    req.previous_tasks.create!(task: first, task_name: "first")

    chain = second.prerequisite_chain
    assert_equal 2, chain.length
    assert_equal "second", chain.first[:name]
    assert_equal "first", chain.last[:name]
  end

  # --- Task 11: chain node carries requirements (player_level + trader_requirements) ---

  test "prerequisite_chain node carries player_level + trader_requirements" do
    first = Task.create!(bsg_id: "np1-#{SecureRandom.hex(4)}", full_name: "First", name: "first", given_by: "Prapor")
    second = Task.create!(bsg_id: "np2-#{SecureRandom.hex(4)}", full_name: "Second", name: "second", given_by: "Therapist")

    req = second.requirements.create!(player_level: 14, trader_level: [ { "trader_name" => "peacekeeper", "trader_level" => "3" } ])
    req.previous_tasks.create!(task: first, task_name: "first")

    chain = second.prerequisite_chain
    assert_equal 14, chain.first[:player_level]
    assert_equal [ { "trader_name" => "peacekeeper", "trader_level" => "3" } ], chain.first[:trader_requirements]

    assert_equal 0, chain.last[:player_level]
    assert_equal [], chain.last[:trader_requirements]
  end

  test "prerequisite_chain full chain length 8 (wet-job 1..6 -> the-guide -> the-cleaner)" do
    # Build the chain that mirrors the source (Task 11 example: M80 unlock path)
    wet1 = Task.create!(bsg_id: "wet1-#{SecureRandom.hex(4)}", full_name: "Wet Job 1", name: "wet-job-part-1", given_by: "Mechanic")
    wet2 = Task.create!(bsg_id: "wet2-#{SecureRandom.hex(4)}", full_name: "Wet Job 2", name: "wet-job-part-2", given_by: "Mechanic")
    wet3 = Task.create!(bsg_id: "wet3-#{SecureRandom.hex(4)}", full_name: "Wet Job 3", name: "wet-job-part-3", given_by: "Mechanic")
    wet4 = Task.create!(bsg_id: "wet4-#{SecureRandom.hex(4)}", full_name: "Wet Job 4", name: "wet-job-part-4", given_by: "Mechanic")
    wet5 = Task.create!(bsg_id: "wet5-#{SecureRandom.hex(4)}", full_name: "Wet Job 5", name: "wet-job-part-5", given_by: "Mechanic")
    wet6 = Task.create!(bsg_id: "wet6-#{SecureRandom.hex(4)}", full_name: "Wet Job 6", name: "wet-job-part-6", given_by: "Mechanic")
    guide = Task.create!(bsg_id: "guide-#{SecureRandom.hex(4)}", full_name: "The Guide", name: "the-guide", given_by: "Peacekeeper")
    cleaner = Task.create!(bsg_id: "cleaner-#{SecureRandom.hex(4)}", full_name: "The Cleaner", name: "the-cleaner", given_by: "Peacekeeper")

    wet1.requirements.create!(player_level: 14, trader_level: [])
    [ wet2, wet3, wet4, wet5 ].each_with_index do |t, i|
      prev = [ wet1, wet2, wet3, wet4 ][i]
      r = t.requirements.create!(player_level: 14, trader_level: [])
      r.previous_tasks.create!(task: prev, task_name: prev.name)
    end
    wet6_r = wet6.requirements.create!(player_level: 0, trader_level: [])
    wet6_r.previous_tasks.create!(task: wet5, task_name: wet5.name)

    guide_r = guide.requirements.create!(player_level: 0, trader_level: [ { "trader_name" => "", "trader_level" => "4" } ])
    guide_r.previous_tasks.create!(task: wet6, task_name: wet6.name)

    cleaner_r = cleaner.requirements.create!(player_level: 0, trader_level: [ { "trader_name" => "peacekeeper", "trader_level" => "3" } ])
    cleaner_r.previous_tasks.create!(task: guide, task_name: guide.name)

    chain = cleaner.prerequisite_chain
    assert_equal 8, chain.length
    expected_slugs = %w[the-cleaner the-guide wet-job-part-6 wet-job-part-5 wet-job-part-4 wet-job-part-3 wet-job-part-2 wet-job-part-1]
    assert_equal expected_slugs, chain.map { |n| n[:name] }

    # wet-job-part-1: lvl 14, no trader (last node — root of the chain)
    wet1_node = chain.last
    assert_equal 14, wet1_node[:player_level]
    assert_equal [], wet1_node[:trader_requirements]

    # the-guide: lvl 0, empty-name trader (LL4)
    guide_node = chain[1]
    assert_equal 0, guide_node[:player_level]
    assert_equal [ { "trader_name" => "", "trader_level" => "4" } ], guide_node[:trader_requirements]

    # the-cleaner: lvl 0, peacekeeper LL3
    cleaner_node = chain.first
    assert_equal 0, cleaner_node[:player_level]
    assert_equal [ { "trader_name" => "peacekeeper", "trader_level" => "3" } ], cleaner_node[:trader_requirements]
  end

  test "prerequisite_chain returns trader_requirements=[] for task with no requirement row" do
    task = Task.create!(bsg_id: "noreq-#{SecureRandom.hex(4)}", full_name: "No Req", name: "no-req", given_by: "Prapor")
    chain = task.prerequisite_chain
    assert_equal 1, chain.length
    assert_equal 0, chain.first[:player_level]
    assert_equal [], chain.first[:trader_requirements]
  end
end
