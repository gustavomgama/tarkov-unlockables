class AddUniqueIndexToFavoriteItems < ActiveRecord::Migration[8.1]
  # FavoriteItem validates uniqueness of item_id, but that is a check-then-insert:
  # two concurrent "add favorite" requests both pass the validation and both
  # insert. Only a database unique index actually prevents the duplicate row.
  disable_ddl_transaction!

  def up
    # Collapse any duplicates a race already produced before adding the
    # constraint, keeping the oldest row for each item.
    execute <<~SQL
      DELETE FROM favorite_items a
      USING favorite_items b
      WHERE a.id > b.id AND a.item_id = b.item_id
    SQL

    remove_index :favorite_items, :item_id, algorithm: :concurrently
    add_index :favorite_items, :item_id, unique: true, algorithm: :concurrently
  end

  def down
    remove_index :favorite_items, :item_id, algorithm: :concurrently
    add_index :favorite_items, :item_id, algorithm: :concurrently
  end
end
