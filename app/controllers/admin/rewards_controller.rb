class Admin::RewardsController < Admin::ApplicationController
  include AdminCrud
  crud_actions model: Reward
  searchable_columns :reward_type

  private

  def resource_params
    params.require(:reward).permit(:task_id, :reward_type)
  end
end
