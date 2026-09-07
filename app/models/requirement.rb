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
class Requirement < ApplicationRecord
  belongs_to :task
  has_many :previous_tasks, dependent: :destroy
end
