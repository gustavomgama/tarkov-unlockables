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
class Requirement < ApplicationRecord
  belongs_to :task
  has_many :previous_tasks, dependent: :destroy

  def self.ransackable_attributes(auth_object = nil)
    %w[player_level]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[previous_tasks task]
  end
end
