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
class LeadsTo < ApplicationRecord
  belongs_to :task, counter_cache: :leads_tos_count
  belongs_to :follow_up_task, class_name: "Task", optional: true

  def self.ransackable_attributes(auth_object = nil)
    %w[follow_up_task_name]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[follow_up_task task]
  end
end
