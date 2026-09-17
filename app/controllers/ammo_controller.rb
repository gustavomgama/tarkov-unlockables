class AmmoController < ApplicationController
  # Every round grouped by caliber, hardest-hitting first within each group.
  # ~200 rounds, so sort and group in Ruby after one query.
  def index
    grouped = Item::Ammo.all.group_by { |round| Item.caliber_display(round.data["caliber"]).presence || "Other" }
    @by_caliber = grouped.sort_by { |caliber, _| caliber }
                         .map do |caliber, rounds|
      [ caliber, rounds.sort_by { |round| -round.data["penetration_power"].to_i } ]
    end
    fresh_when(etag: [ Item::Ammo.maximum(:updated_at), @by_caliber.size ], public: true)
  end
end
