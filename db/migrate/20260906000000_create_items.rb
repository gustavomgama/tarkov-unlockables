class CreateItems < ActiveRecord::Migration[8.1]
  def change
    create_table :items do |t|
      t.string :type, null: false, default: "Item::Generic"
      t.string :bsg_id
      t.string :slug
      t.string :full_name
      t.string :short_name
      t.string :wiki_title
      t.text :categories, array: true, default: []
      t.text :links, array: true, default: []
      t.text :images, array: true, default: []
      t.jsonb :data, null: false, default: {}
      t.timestamps
    end
    add_index :items, :bsg_id, unique: true
    add_index :items, :type
    add_index :items, :slug
  end
end