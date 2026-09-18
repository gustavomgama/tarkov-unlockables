# frozen_string_literal: true

class CreateTaskObjectives < ActiveRecord::Migration[8.1]
  def change
    # Canonical carries 1,457 objectives across 517 tasks, with a resolved
    # human description (0 raw ids). This is the "what do I have to do" the
    # task page could not answer. Store order, because the source order is
    # how the game lists them.
    create_table :task_objectives do |t|
      t.references :task, null: false, foreign_key: true, index: true
      t.string :objective_id
      t.string :objective_type
      t.text :description
      t.integer :count
      t.boolean :optional, default: false, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end
  end
end
