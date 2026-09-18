# frozen_string_literal: true

class CreateTaskObjectiveItems < ActiveRecord::Migration[8.1]
  def change
    # The items an objective accepts (canonical `raw.items`). The importer
    # skips catch-alls with 100+ ids ("sell any items to Ragman"), which are a
    # category, not a hand-in.
    create_table :task_objective_items do |t|
      t.references :task_objective, null: false, foreign_key: true, index: true
      t.references :item, foreign_key: true
      t.string :item_name
      t.timestamps
    end
  end
end
