class MapsController < ApplicationController
  def index
    @maps = Map.order(:name)
    fresh_when(@maps, public: true)
  end

  def show
    @map = Map.find_by!(slug: params[:slug])
    fresh_when(@map, public: true)
  end
end
