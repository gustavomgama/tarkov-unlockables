# frozen_string_literal: true

class AddNeededKeysToTasks < ActiveRecord::Migration[8.1]
  def change
    # 57 keys over 57 tasks. Small and display-only, so jsonb: a flat array of
    # { map_name, item_id, item_name }, grouped by map in the view.
    add_column :tasks, :needed_keys, :jsonb, null: false, default: []
  end
end
