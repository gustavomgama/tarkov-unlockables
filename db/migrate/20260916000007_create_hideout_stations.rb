# frozen_string_literal: true

class CreateHideoutStations < ActiveRecord::Migration[8.1]
  def change
    # 26 stations, 68 levels. Item requirements (317) get a table so an item
    # page can link to what it builds; station and trader requirements are
    # display-only and small, so they stay as jsonb on the level.
    create_table :hideout_stations do |t|
      t.string :bsg_id
      t.string :slug
      t.string :name
      t.string :image_url
      t.integer :area_type
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :hideout_stations, :bsg_id, unique: true
    add_index :hideout_stations, :slug, unique: true

    create_table :hideout_levels do |t|
      t.references :hideout_station, null: false, foreign_key: true, index: true
      t.integer :level
      t.integer :construction_time
      t.jsonb :station_requirements, null: false, default: []
      t.jsonb :trader_requirements, null: false, default: []
      t.timestamps
    end

    create_table :hideout_item_requirements do |t|
      t.references :hideout_level, null: false, foreign_key: true, index: true
      t.references :item, foreign_key: true
      t.string :item_name
      t.integer :count
      t.boolean :found_in_raid, null: false, default: false
      t.timestamps
    end
  end
end
