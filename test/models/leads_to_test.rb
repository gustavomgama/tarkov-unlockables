require "test_helper"

# == Schema Information
#
# Table name: leads_tos
#
#  id                  :bigint           not null, primary key
#  task_id             :bigint           not null
#  follow_up_task_id   :bigint
#  follow_up_task_name :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_leads_tos_on_follow_up_task_id  (follow_up_task_id)
#  index_leads_tos_on_task_id            (task_id)
#
# Foreign Keys
#
#  fk_rails_...  (follow_up_task_id => tasks.id)
#  fk_rails_...  (task_id => tasks.id)
#
class LeadsToTest < ActiveSupport::TestCase
  test "belongs to task with counter cache" do
    task = Task.create!(bsg_id: "lt-#{SecureRandom.hex(4)}", full_name: "Lead", name: "lead")
    leads_to = task.leads_tos.create!(follow_up_task_name: "Next")

    assert_equal task.id, leads_to.task_id
    assert_equal 1, task.reload.leads_tos_count
  end

  test "follow_up_task association is optional" do
    task = Task.create!(bsg_id: "lt2-#{SecureRandom.hex(4)}", full_name: "Lead2", name: "lead2")
    leads_to = LeadsTo.create!(task: task, follow_up_task_name: "Unresolved")
    assert_nil leads_to.follow_up_task

    follow = Task.create!(bsg_id: "lt3-#{SecureRandom.hex(4)}", full_name: "Follow", name: "follow")
    leads_to.update!(follow_up_task: follow)
    assert_equal follow, leads_to.follow_up_task
  end
end
