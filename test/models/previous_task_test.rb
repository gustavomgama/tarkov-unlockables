require "test_helper"

# == Schema Information
#
# Table name: previous_tasks
#
#  id             :bigint           not null, primary key
#  requirement_id :bigint           not null
#  task_id        :bigint
#  task_name      :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
# Indexes
#
#  index_previous_tasks_on_requirement_id  (requirement_id)
#  index_previous_tasks_on_task_id         (task_id)
#
# Foreign Keys
#
#  fk_rails_...  (requirement_id => requirements.id)
#  fk_rails_...  (task_id => tasks.id)
#
class PreviousTaskTest < ActiveSupport::TestCase
  test "belongs to requirement with counter cache" do
    task = Task.create!(bsg_id: "pt-#{SecureRandom.hex(4)}", full_name: "PT", name: "pt")
    requirement = task.requirements.create!(player_level: 1)

    previous = requirement.previous_tasks.create!(task_name: "First")
    assert_equal requirement.id, previous.requirement_id
    assert_equal 1, requirement.reload.previous_tasks_count
  end

  test "task association is optional" do
    task = Task.create!(bsg_id: "pt2-#{SecureRandom.hex(4)}", full_name: "PT2", name: "pt2")
    requirement = task.requirements.create!(player_level: 1)

    previous = PreviousTask.create!(requirement: requirement, task_name: "Unknown")
    assert_nil previous.task

    first = Task.create!(bsg_id: "pt3-#{SecureRandom.hex(4)}", full_name: "First", name: "first")
    previous.update!(task: first)
    assert_equal first, previous.task
  end
end
