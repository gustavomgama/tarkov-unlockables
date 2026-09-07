class Admin::PreviousTasksController < Admin::ApplicationController
  include AdminCrud
  crud_actions model: PreviousTask

  private

  def resource_params
    params.require(:previous_task).permit(:requirement_id, :task_id, :task_name)
  end
end
