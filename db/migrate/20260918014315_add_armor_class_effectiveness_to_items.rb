class AddArmorClassEffectivenessToItems < ActiveRecord::Migration[8.1]
  # The wiki's ballistics chart, one 0-6 effectiveness level per armor class.
  # Empty for every item that is not on the chart (and for the 14 rounds the
  # snapshot lacks), which the views read as "no wiki data".
  def change
    add_column :items, :armor_class_effectiveness, :jsonb, default: {}, null: false
  end
end
