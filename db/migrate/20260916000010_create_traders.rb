# frozen_string_literal: true

class CreateTraders < ActiveRecord::Migration[8.1]
  def change
    # 16 traders with their loyalty-level thresholds, the answer to "can I
    # buy this yet". Offers stay on item_currencies, keyed by the trader name.
    create_table :traders do |t|
      t.string :bsg_id
      t.string :slug
      t.string :name
      t.text :description
      t.string :currency
      t.string :image_url
      t.integer :task_count
      t.timestamps
    end
    add_index :traders, :bsg_id, unique: true
    add_index :traders, :slug, unique: true

    create_table :trader_levels do |t|
      t.references :trader, null: false, foreign_key: true, index: true
      t.integer :level
      t.integer :required_player_level
      t.float :required_reputation
      t.float :required_commerce
      t.float :pay_rate
      t.float :insurance_rate
      t.float :repair_cost_multiplier
      t.timestamps
    end
  end
end
