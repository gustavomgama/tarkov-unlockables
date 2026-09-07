class Admin::LeadsTosController < Admin::ApplicationController
  include AdminCrud
  crud_actions model: LeadsTo

  private

  def resource_params
    params.require(:leads_to).permit(:task_id, :follow_up_task_id, :follow_up_task_name)
  end
end
