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

    # `if_exists`/`if_not_exists` so a database that already ran this under its
    # earlier timestamp converges instead of aborting.
    remove_index :favorite_items, :item_id, algorithm: :concurrently, if_exists: true
    add_index :favorite_items, :item_id, unique: true, algorithm: :concurrently, if_not_exists: true
  end

  def down
    remove_index :favorite_items, :item_id, algorithm: :concurrently
    add_index :favorite_items, :item_id, algorithm: :concurrently
  end
end
