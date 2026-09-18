class TradersController < ApplicationController
  OFFERS_PER_LEVEL = 25

  def index
    @traders = Trader.order(:name)
    # Grouped counts instead of preloads; the cards only show the sizes.
    @offer_counts = ItemCurrency.group(:trader).distinct.count(:item_id)
    @level_counts = TraderLevel.group(:trader_id).count
    fresh_when(@traders, public: true)
  end

  def show
    @trader = Trader.find_by!(slug: params[:slug])
    fresh_when(@trader, public: true)
    return if performed?

    ActiveRecord::Associations::Preloader.new(records: [ @trader ], associations: [ :trader_levels ]).call
    # Offers are keyed by the trader's display name (item_currencies.trader).
    @offers_by_level = ItemCurrency.where(trader: @trader.name).includes(:item).group_by(&:min_trader_level)
  end
end
