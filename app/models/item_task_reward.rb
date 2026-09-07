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
class ItemTaskReward < ApplicationRecord
  belongs_to :item
  belongs_to :task, optional: true
end
