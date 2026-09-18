# frozen_string_literal: true

class AddExperienceAndFactionToTasks < ActiveRecord::Migration[8.1]
  def change
    # Canonical gives every task an XP reward and a faction (Any/BEAR/USEC).
    # The faction is a display chip; the XP is shown in the task readout.
    add_column :tasks, :experience, :integer
    add_column :tasks, :faction, :string
  end
end
