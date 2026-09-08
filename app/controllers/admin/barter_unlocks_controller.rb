class Admin::BarterUnlocksController < Admin::ApplicationController
  include AdminCrud
  crud_actions model: BarterUnlock
  searchable_columns :item_name

  private

  def resource_params
    params.require(:barter_unlock).permit(:reward_id, :item_id, :item_name)
  end
end
