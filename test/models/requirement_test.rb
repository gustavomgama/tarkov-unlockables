require "test_helper"

# == Schema Information
#
# Table name: requirements
#
#  id                   :bigint           not null, primary key
#  task_id              :bigint           not null
#  player_level         :integer
#  previous_tasks_count :integer          default(0), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  trader_level         :jsonb            not null
#
# Indexes
#
#  index_requirements_on_task_id  (task_id)
#
# Foreign Keys
#
#  fk_rails_...  (task_id => tasks.id)
#
class RequirementTest < ActiveSupport::TestCase
  test "belongs to task" do
    task = Task.create!(bsg_id: "rq-#{SecureRandom.hex(4)}", full_name: "Req", name: "req")
    requirement = Requirement.create!(task: task, player_level: 5)
    assert_equal task, requirement.task
  end

  test "has many previous_tasks with counter cache" do
    task = Task.create!(bsg_id: "rq2-#{SecureRandom.hex(4)}", full_name: "Req2", name: "req2")
    requirement = task.requirements.create!(player_level: 5)
    assert_equal 0, requirement.previous_tasks_count

    requirement.previous_tasks.create!(task_name: "First")
    assert_equal 1, requirement.reload.previous_tasks_count
  end

  # --- Task 11: trader_level jsonb column (default []) ---

  test "trader_level defaults to empty array" do
    task = Task.create!(bsg_id: "tl1-#{SecureRandom.hex(4)}", full_name: "TL", name: "tl")
    req = task.requirements.create!(player_level: 5)
    assert_equal [], req.trader_level
  end

  test "trader_level accepts array of {trader_name, trader_level} hashes" do
    task = Task.create!(bsg_id: "tl2-#{SecureRandom.hex(4)}", full_name: "TL2", name: "tl2")
    req = task.requirements.create!(
      player_level: 0,
      trader_level: [ { "trader_name" => "peacekeeper", "trader_level" => "3" } ]
    )
    assert_equal [ { "trader_name" => "peacekeeper", "trader_level" => "3" } ], req.trader_level
  end
end
