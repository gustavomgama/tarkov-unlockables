require "test_helper"

# == Schema Information
#
# Table name: item_task_rewards
#
#  id         :bigint           not null, primary key
#  item_id    :bigint           not null
#  task_id    :bigint
#  task_name  :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_item_task_rewards_on_item_id  (item_id)
#  index_item_task_rewards_on_task_id  (task_id)
#
# Foreign Keys
#
#  fk_rails_...  (item_id => items.id)
#  fk_rails_...  (task_id => tasks.id)
#
class ItemTaskRewardTest < ActiveSupport::TestCase
  test "belongs to item and optional task" do
    item = Item.create!(bsg_id: "itr-#{SecureRandom.hex(4)}", full_name: "ITR", short_name: "ITR")
    itr = item.item_task_rewards.create!(task_name: "Debut")
    assert_equal item, itr.item
    assert_nil itr.task

    task = Task.create!(bsg_id: "itr2-#{SecureRandom.hex(4)}", full_name: "Debut", name: "debut")
    itr.update!(task: task)
    assert_equal task, itr.task
  end
end
