class AddPreviousTasksCountToRequirements < ActiveRecord::Migration[8.1]
  def change
    add_column :requirements, :previous_tasks_count, :integer, default: 0
    Requirement.reset_column_information
    Requirement.find_each { |r| Requirement.reset_counters(r.id, :previous_tasks) }
  end
end
