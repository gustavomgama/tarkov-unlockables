class AddTraderLevelToRequirements < ActiveRecord::Migration[8.1]
  def change
    add_column :requirements, :trader_level, :jsonb, null: false, default: []
  end
end
