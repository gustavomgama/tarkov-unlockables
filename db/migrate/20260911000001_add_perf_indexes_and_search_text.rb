class AddPerfIndexesAndSearchText < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pg_trgm" unless extension_enabled?("pg_trgm")

    # Stripped, lowercased text for loose search — populated by model
    # callback, backfilled below. Lets search hit a trigram GIN index
    # instead of regexp_replace() seq-scanning every row per keystroke.
    add_column :items, :search_text, :string, default: "", null: false
    add_column :tasks, :search_text, :string, default: "", null: false

    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE items SET search_text = lower(regexp_replace(coalesce(full_name,'') || ' ' || coalesce(short_name,''), '[^a-zA-Z0-9]', '', 'g'));
          UPDATE tasks SET search_text = lower(regexp_replace(coalesce(full_name,'') || ' ' || coalesce(name,''), '[^a-zA-Z0-9]', '', 'g'));
        SQL
      end
    end

    change_column_null :items, :search_text, false
    change_column_null :tasks, :search_text, false

    add_index :items, :search_text, using: :gin, opclass: :gin_trgm_ops, name: "index_items_on_search_text_trgm"
    add_index :tasks, :search_text, using: :gin, opclass: :gin_trgm_ops, name: "index_tasks_on_search_text_trgm"

    # ORDER BY / filter hot paths (were seq scans + sorts)
    add_index :items, :full_name
    add_index :items, :categories, using: :gin
    add_index :tasks, :full_name
    add_index :tasks, :given_by
    add_index :tasks, :name
    add_index :item_currencies, :currency
    add_index :item_currencies, :trader
  end
end
