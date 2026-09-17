# frozen_string_literal: true

class AddAlternativeToPreviousTasks < ActiveRecord::Migration[8.1]
  def change
    # The wiki joins some prerequisites with `or`: the player needs any one of
    # them, not all. The chain still shows them, marked as alternatives.
    add_column :previous_tasks, :alternative, :boolean, null: false, default: false
  end
end
