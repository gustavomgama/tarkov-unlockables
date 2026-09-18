class AddExpressionIndexesForCaliberAndClass < ActiveRecord::Migration[8.1]
  # `data->>'caliber'` and `data->>'class'` are filtered, grouped and counted on
  # the items index (per-caliber option counts, the caliber filter, the ammo
  # comparison, the class dropdown) and by the importer's caliber backfill. The
  # jsonb GIN index cannot serve `->>` equality, so each of those was a
  # sequential scan.
  #
  # Measured on the real dataset (3,399 items): the items index's cold
  # filter-option pass cost 349ms of SQL without these indexes and 27ms with
  # them — 390ms → 61ms end to end. The hot paths (every ammo page, every
  # caliber-filtered listing) benefit the same way.
  # Concurrently: both indexes are built without holding a write lock on the
  # items table.
  disable_ddl_transaction!

  def change
    add_index :items, "(data->>'caliber')", name: "index_items_on_data_caliber",
                algorithm: :concurrently, if_not_exists: true
    add_index :items, "(data->>'class')", name: "index_items_on_data_class",
                algorithm: :concurrently, if_not_exists: true
  end
end
