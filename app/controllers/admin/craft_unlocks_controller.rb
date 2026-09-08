class Admin::CraftUnlocksController < Admin::ApplicationController
  include AdminCrud
  crud_actions model: CraftUnlock
  searchable_columns :item_name, :hideout_station

  private

  def resource_params
    params.require(:craft_unlock).permit(:reward_id, :item_id, :item_name, :hideout_station, :station_level)
  end
end
