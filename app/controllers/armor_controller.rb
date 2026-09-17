class ArmorController < ApplicationController
  # Body armor by armor class, toughest first within each class. Ballistic
  # plates and helmets live in their own item classes and are not included.
  def index
    @by_class = Item::Armor.all
                           .group_by { |armor| armor.data["class"].to_i }
                           .sort_by { |armor_class, _| -armor_class }
                           .map do |armor_class, armors|
      [ armor_class, armors.sort_by { |armor| -armor.data["durability"].to_i } ]
    end
    fresh_when(etag: [ Item::Armor.maximum(:updated_at), @by_class.size ], public: true)
  end
end
