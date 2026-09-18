class StationsController < ApplicationController
  # The hideout index only changes on import.
  def index
    @stations = HideoutStation.order(:position)
    # One grouped count instead of a preload: the view only needs the size,
    # and Bullet reads an unused preload as a wasted query.
    @level_counts = HideoutLevel.group(:hideout_station_id).count
    fresh_when(@stations, public: true)
  end

  def show
    @station = HideoutStation.find_by!(slug: params[:slug])
    fresh_when(@station, public: true)
    return if performed?

    ActiveRecord::Associations::Preloader.new(
      records: [ @station ], associations: [ { hideout_levels: :hideout_item_requirements } ]
    ).call
    # What the station produces, keyed by level, in one query.
    @crafts_by_level = ItemHideout.where(station: @station.name).includes(:item).group_by(&:level)
  end
end
