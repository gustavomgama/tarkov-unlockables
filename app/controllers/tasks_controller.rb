class TasksController < ApplicationController
  def index
    tasks = Task.all
    tasks = tasks.loose_search(params[:q], columns: %w[full_name name]) if params[:q].present?
    tasks = tasks.where(given_by: params[:trader]) if params[:trader].present?
    @tasks = tasks.order(full_name: :asc)
    @task_count = tasks.count
    @traders = Task.distinct.pluck(:given_by).compact.sort
  end

  def show
    @task = Task.includes(
      requirements: :previous_tasks,
      rewards: [ { loose_items: :item }, :offer_unlocks, :barter_unlocks, :craft_unlocks ],
      leads_tos: :follow_up_task
    ).find(params[:id])
  end

  def chains
    @tasks = Task.includes(requirements: :previous_tasks).order(full_name: :asc)
  end
end
