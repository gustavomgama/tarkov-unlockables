# frozen_string_literal: true

class AddRecipesToBarterAndCraftRoutes < ActiveRecord::Migration[8.1]
  def change
    # A barter offer now carries its recipe and economics. The offered item is
    # the row's own `item`, so only the inputs need a child table.
    add_column :item_barters, :barter_id, :string
    add_column :item_barters, :count, :integer, default: 1, null: false
    add_column :item_barters, :buy_limit, :integer
    add_column :item_barters, :restock_amount, :bigint
    add_reference :item_barters, :task, foreign_key: true, index: true
    add_index :item_barters, :barter_id

    create_table :item_barter_requirements do |t|
      # Cascade: Item deletes its barters with `delete_all`, which would
      # otherwise hit these rows' RESTRICT foreign key.
      t.references :item_barter, null: false, index: true,
                   foreign_key: { on_delete: :cascade }
      t.references :item, foreign_key: true
      t.string :item_name
      t.integer :count
      t.timestamps
    end

    # Same for hideout crafts: duration + tool flags + inputs.
    add_column :item_hideouts, :craft_id, :string
    add_column :item_hideouts, :count, :integer, default: 1, null: false
    add_column :item_hideouts, :duration, :integer
    add_reference :item_hideouts, :task, foreign_key: true, index: true
    add_index :item_hideouts, :craft_id

    create_table :item_hideout_requirements do |t|
      t.references :item_hideout, null: false, index: true,
                   foreign_key: { on_delete: :cascade }
      t.references :item, foreign_key: true
      t.string :item_name
      t.integer :count
      t.boolean :is_tool, default: false, null: false
      t.timestamps
    end
  end
end
