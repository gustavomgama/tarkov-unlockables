class Admin::RewardsController < Admin::ApplicationController
  include AdminCrud
  crud_actions model: Reward

  private

  def resource_params
    params.require(:reward).permit(:task_id, :reward_type)
  end
end
