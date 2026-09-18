# frozen_string_literal: true

class CreateMaps < ActiveRecord::Migration[8.1]
  def change
    # 17 maps with their raid info and four small display-only lists (152
    # extracts, 129 bosses, 33 transits), so jsonb rather than four tables.
    create_table :maps do |t|
      t.string :bsg_id
      t.string :slug
      t.string :name
      t.string :name_id
      t.string :wiki_link
      t.text :description
      t.integer :raid_duration
      t.string :players
      t.jsonb :enemies, null: false, default: []
      t.jsonb :bosses, null: false, default: []
      t.jsonb :extracts, null: false, default: []
      t.jsonb :transits, null: false, default: []
      t.timestamps
    end
    add_index :maps, :bsg_id, unique: true
    add_index :maps, :slug, unique: true
  end
end
