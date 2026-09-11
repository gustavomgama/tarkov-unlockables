class FavoritesController < ApplicationController
  def index
    @favorite_items = FavoriteItem.includes(:item).map(&:item).compact
  end

  def create
    @favorite = FavoriteItem.new(item_id: params[:item_id])
    if @favorite.save
      redirect_back fallback_location: root_path, notice: "Added to favorites."
    else
      redirect_back fallback_location: root_path, alert: "Could not add favorite."
    end
  end

  def destroy
    @favorite = FavoriteItem.find_by(item_id: params[:item_id])
    @favorite&.destroy
    redirect_back fallback_location: root_path, notice: "Removed from favorites."
  end
end
