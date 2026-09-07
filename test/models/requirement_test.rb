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
end
