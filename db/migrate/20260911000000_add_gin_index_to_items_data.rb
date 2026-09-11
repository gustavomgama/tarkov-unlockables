# frozen_string_literal: true

# GIN index over the items.data jsonb column. Item#ammo_packs queries
# data->'containsItems' @> … on every item show page; without an index that
# is a sequential scan of the whole items table per request.
class AddGinIndexToItemsData < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :items, :data, using: :gin, algorithm: :concurrently
  end
end
