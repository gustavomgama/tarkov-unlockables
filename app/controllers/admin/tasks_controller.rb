class Admin::TasksController < Admin::ApplicationController
  include AdminCrud
  crud_actions model: Task

  private

  def resource_params
    params.require(:task).permit(:bsg_id, :full_name, :name, :wiki_link, :given_by, :kappa_required, :lightkeeper_required)
  end
end
