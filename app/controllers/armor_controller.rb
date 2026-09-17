class ArmorController < ApplicationController
  HELMET_TYPE = "ItemPropertiesHelmet"

  # Body armor and helmets by armor class, toughest first within each class.
  # Plates and face shields live on other items and are not charts of their own.
  def index
    @armor_by_class = by_class(Item::Armor.all)
    @helmets_by_class = by_class(Item.where("data->>'propertiesType' = ?", HELMET_TYPE))
    fresh_when(etag: [ Item.maximum(:updated_at), @armor_by_class.size, @helmets_by_class.size ], public: true)
  end

  private

  def by_class(scope)
    scope.group_by { |item| item.data["class"].to_i }
         .sort_by { |armor_class, _| -armor_class }
         .map do |armor_class, items|
      [ armor_class, items.sort_by { |item| -item.data["durability"].to_i } ]
    end
  end
end
