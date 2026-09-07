# == Schema Information
#
# Table name: leads_tos
#
#  id                  :bigint           not null, primary key
#  task_id             :bigint
#  follow_up_task_id   :string
#  follow_up_task_name :string
#
# Indexes
#
#  index_leads_tos_on_task_id  (task_id)
#
# Foreign Keys
#
#  fk_rails_...  (task_id => tasks.id)
#
class LeadsTo < ApplicationRecord
  belongs_to :task, foreign_key: :task_id, counter_cache: true

  def follow_up_task
    return nil unless follow_up_task_id.present?
    @follow_up_task ||= Task.find_by(id: follow_up_task_id.to_i)
  end
end
