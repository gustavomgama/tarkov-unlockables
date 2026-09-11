class CreateFavoriteItems < ActiveRecord::Migration[8.1]
  def change
    create_table :favorite_items do |t|
      t.bigint :item_id, null: false
      t.timestamps
    end
    add_index :favorite_items, :item_id
    add_foreign_key :favorite_items, :items, column: :item_id, on_delete: :restrict
  end
end
