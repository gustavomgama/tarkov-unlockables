class AddLeadsTosCountToTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :tasks, :leads_tos_count, :integer, default: 0
    Task.reset_column_information
    Task.find_each { |t| Task.reset_counters(t.id, :leads_tos) }
  end
end
