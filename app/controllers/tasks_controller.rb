class TasksController < ApplicationController
  def index
    tasks = Task.all
    tasks = tasks.loose_search(params[:q], columns: %w[full_name name]) if params[:q].present?
    @tasks = tasks.order(full_name: :asc)
    @task_count = tasks.count
  end

  def show
    @task = Task.includes(
      requirements: :previous_tasks,
      rewards: [ { loose_items: :item }, :offer_unlocks, :barter_unlocks, :craft_unlocks ],
      leads_tos: :task
    ).find(params[:id])
  end

  def chains
    @tasks = Task.includes(requirements: :previous_tasks).order(full_name: :asc).limit(50)
  end
end
