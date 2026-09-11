class ApplicationController < ActionController::Base
  include LooseSearchable

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, CSS :has.
  allow_browser versions: :modern

  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActionController::RoutingError, with: :not_found
  rescue_from StandardError, with: :internal_server_error unless Rails.env.development?

  # Preloaded name → task map shared by every Task#prerequisite_chain call
  # in views. Lazy per request: pages that render no raid timeline issue
  # zero queries for it (and never trip Bullet's unused-preload check).
  def task_map
    @task_map ||= Task.includes(requirements: :previous_tasks).index_by(&:name)
  end
  helper_method :task_map

  private

  def not_found
    render "errors/not_found", status: :not_found
  end

  def internal_server_error
    render "errors/internal_server_error", status: :internal_server_error
  end
end
