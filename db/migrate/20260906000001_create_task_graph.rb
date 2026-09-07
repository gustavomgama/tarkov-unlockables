class CreateTaskGraph < ActiveRecord::Migration[8.1]
  def change
    # --- tasks (created first: item_task_rewards references tasks) ---
    create_table :tasks do |t|
      t.string :bsg_id
      t.string :full_name
      t.string :name
      t.string :wiki_link
      t.string :given_by
      t.boolean :kappa_required
      t.boolean :lightkeeper_required
      t.integer :leads_tos_count, null: false, default: 0
      t.timestamps
    end

    # --- obtain graph (item → how to get it) ---
    create_table :item_currencies do |t|
      t.references :item, null: false, foreign_key: true
      t.string :trader
      t.string :currency
      t.integer :min_trader_level
      t.boolean :task_unlock, null: false, default: false
      t.timestamps
    end

    create_table :item_task_rewards do |t|
      t.references :item, null: false, foreign_key: true
      t.references :task, foreign_key: true
      t.string :task_name
      t.timestamps
    end

    create_table :item_hideouts do |t|
      t.references :item, null: false, foreign_key: true
      t.string :station
      t.integer :level
      t.timestamps
    end

    create_table :item_barters do |t|
      t.references :item, null: false, foreign_key: true
      t.string :trader
      t.string :trader_level
      t.string :currency
      t.integer :cost
      t.string :item_name
      t.timestamps
    end

    # --- task graph ---
    create_table :leads_tos do |t|
      t.references :task, null: false, foreign_key: true
      t.references :follow_up_task, foreign_key: { to_table: :tasks }
      t.string :follow_up_task_name
      t.timestamps
    end

    create_table :requirements do |t|
      t.references :task, null: false, foreign_key: true
      t.integer :player_level
      t.integer :previous_tasks_count, null: false, default: 0
      t.timestamps
    end

    create_table :previous_tasks do |t|
      t.references :requirement, null: false, foreign_key: true
      t.references :task, foreign_key: true
      t.string :task_name
      t.timestamps
    end

    create_table :rewards do |t|
      t.references :task, null: false, foreign_key: true
      t.string :reward_type
      t.timestamps
    end

    # --- unlock graph (item_id = FK to items.id, resolved at import) ---
    create_table :loose_items do |t|
      t.references :reward, null: false, foreign_key: true
      t.references :item, foreign_key: true
      t.string :item_name
      t.integer :count
      t.timestamps
    end

    create_table :offer_unlocks do |t|
      t.references :reward, null: false, foreign_key: true
      t.references :item, foreign_key: true
      t.string :item_name
      t.string :trader_name
      t.string :trader_level
      t.timestamps
    end

    create_table :barter_unlocks do |t|
      t.references :reward, null: false, foreign_key: true
      t.references :item, foreign_key: true
      t.string :item_name
      t.timestamps
    end

    create_table :barter_requirements do |t|
      t.references :barter_unlock, null: false, foreign_key: true
      t.string :trader_name
      t.string :trader_level
      t.timestamps
    end

    create_table :barter_requirement_items do |t|
      t.references :barter_requirement, null: false, foreign_key: true
      t.references :item, foreign_key: true
      t.string :item_name
      t.integer :count
      t.timestamps
    end

    create_table :barter_results do |t|
      t.references :barter_unlock, null: false, foreign_key: true
      t.timestamps
    end

    create_table :barter_result_items do |t|
      t.references :barter_result, null: false, foreign_key: true
      t.references :item, foreign_key: true
      t.string :item_name
      t.timestamps
    end

    create_table :craft_unlocks do |t|
      t.references :reward, null: false, foreign_key: true
      t.references :item, foreign_key: true
      t.string :item_name
      t.string :hideout_station
      t.integer :station_level
      t.timestamps
    end

    create_table :craft_requirements do |t|
      t.references :craft_unlock, null: false, foreign_key: true
      t.string :trader_name
      t.string :trader_level
      t.timestamps
    end

    create_table :craft_requirement_items do |t|
      t.references :craft_requirement, null: false, foreign_key: true
      t.references :item, foreign_key: true
      t.string :item_name
      t.integer :count
      t.timestamps
    end

    create_table :craft_results do |t|
      t.references :craft_unlock, null: false, foreign_key: true
      t.timestamps
    end

    create_table :craft_result_items do |t|
      t.references :craft_result, null: false, foreign_key: true
      t.references :item, foreign_key: true
      t.string :item_name
      t.timestamps
    end
  end
end