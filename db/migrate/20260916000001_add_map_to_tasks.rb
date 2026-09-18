# frozen_string_literal: true

class AddMapToTasks < ActiveRecord::Migration[8.1]
  def change
    # Canonical carries the task's map (id + display name) for all 517 tasks.
    # Denormalized on purpose: the app only needs to label and filter by map,
    # so a full maps table (extracts, bosses, transits) can wait until a
    # feature needs it.
    add_column :tasks, :map_id, :string
    add_column :tasks, :map_name, :string
    add_index :tasks, :map_name
  end
end
