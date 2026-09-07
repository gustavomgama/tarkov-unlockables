class TasksController < ApplicationController
  def index
    @tasks = Task.includes(requirements: :previous_tasks).order(full_name: :asc).limit(20)
    @task_count = Task.count
  end

  def show
    @task = Task.includes(
      requirements: :previous_tasks,
      rewards: [ :loose_items, :offer_unlocks, :barter_unlocks, :craft_unlocks ],
      leads_tos: :task
    ).find(params[:id])
  end

  def chains
    @tasks = Task.includes(requirements: :previous_tasks).order(full_name: :asc).limit(50)
  end
end
