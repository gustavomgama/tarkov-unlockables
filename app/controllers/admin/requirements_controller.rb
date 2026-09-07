class Admin::RequirementsController < Admin::ApplicationController
  include AdminCrud
  crud_actions model: Requirement

  private

  def resource_params
    params.require(:requirement).permit(:task_id, :player_level, :previous_tasks_count)
  end
end
