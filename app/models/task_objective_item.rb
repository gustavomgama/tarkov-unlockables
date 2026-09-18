# == Schema Information
#
# Table name: task_objective_items
#
#  id                :bigint           not null, primary key
#  task_objective_id :bigint           not null
#  item_id           :bigint
#  item_name         :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Indexes
#
#  index_task_objective_items_on_item_id            (item_id)
#  index_task_objective_items_on_task_objective_id  (task_objective_id)
#
# Foreign Keys
#
#  fk_rails_...  (item_id => items.id)
#  fk_rails_...  (task_objective_id => task_objectives.id)
#
class TaskObjectiveItem < ApplicationRecord
  belongs_to :task_objective
  belongs_to :item, optional: true
end
