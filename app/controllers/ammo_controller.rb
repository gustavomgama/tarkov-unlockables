class AmmoController < ApplicationController
  # Every round grouped by caliber, hardest-hitting first within each group.
  # `min_class` keeps only rounds that defeat at least that armor class.
  def index
    @min_class = params[:min_class].to_i.clamp(0, 6)
    grouped = Item::Ammo.all.group_by { |round| Item.caliber_display(round.data["caliber"]).presence || "Other" }
    @by_caliber = grouped.sort_by { |caliber, _| caliber }
                         .map do |caliber, rounds|
      rounds = rounds.select { |round| round.defeats_class >= @min_class } if @min_class.positive?
      [ caliber, rounds.sort_by { |round| -round.data["penetration_power"].to_i } ]
    end
    @by_caliber.reject! { |_, rounds| rounds.empty? }
    fresh_when(etag: [ Item::Ammo.maximum(:updated_at), @by_caliber.size, @min_class ], public: true)
  end
end
