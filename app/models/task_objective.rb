# == Schema Information
#
# Table name: task_objectives
#
#  id             :bigint           not null, primary key
#  task_id        :bigint           not null
#  objective_id   :string
#  objective_type :string
#  description    :text
#  count          :integer
#  optional       :boolean          default(FALSE), not null
#  position       :integer          default(0), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
# Indexes
#
#  index_task_objectives_on_task_id  (task_id)
#
# Foreign Keys
#
#  fk_rails_...  (task_id => tasks.id)
#
class TaskObjective < ApplicationRecord
  belongs_to :task
end
