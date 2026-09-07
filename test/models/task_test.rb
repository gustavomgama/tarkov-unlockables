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
end
