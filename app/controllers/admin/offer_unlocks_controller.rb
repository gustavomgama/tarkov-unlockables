class Admin::OfferUnlocksController < Admin::ApplicationController
  include AdminCrud
  crud_actions model: OfferUnlock
  searchable_columns :item_name, :trader_name

  private

  def resource_params
    params.require(:offer_unlock).permit(:reward_id, :item_id, :item_name, :trader_name, :trader_level)
  end
end
