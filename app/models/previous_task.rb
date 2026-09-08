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
class PreviousTask < ApplicationRecord
  belongs_to :requirement, counter_cache: :previous_tasks_count
  belongs_to :task, optional: true

  def self.ransackable_attributes(auth_object = nil)
    %w[task_name]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[requirement task]
  end
end
