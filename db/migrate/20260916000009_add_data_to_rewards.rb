# frozen_string_literal: true

class AddDataToRewards < ActiveRecord::Migration[8.1]
  def change
    # Reward kinds with no table of their own: trader standing (362 rows),
    # skill levels (136), achievements, customizations, trader/dialogue
    # unlocks. Display-only and small, so one jsonb column on the reward.
    add_column :rewards, :data, :jsonb, null: false, default: {}
  end
end
