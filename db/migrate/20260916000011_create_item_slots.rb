# frozen_string_literal: true

class CreateItemSlots < ActiveRecord::Migration[8.1]
  def change
    # 3,564 mod slots over 1,278 items and 39,910 "this item fits here" edges.
    # The cascade lets Item's delete_all drop slots without tripping the FK.
    create_table :item_slots do |t|
      t.references :item, null: false, foreign_key: true, index: true
      t.string :slot_id
      t.string :name_id
      t.string :name
      t.boolean :required, null: false, default: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    create_table :item_slot_allowed_items do |t|
      t.references :item_slot, null: false, index: true,
                   foreign_key: { on_delete: :cascade }
      t.references :item, foreign_key: true
      t.timestamps
    end
  end
end
