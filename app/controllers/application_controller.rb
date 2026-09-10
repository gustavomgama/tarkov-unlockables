class ApplicationController < ActionController::Base
  include LooseSearchable

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, CSS :has.
  allow_browser versions: :modern

  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActionController::RoutingError, with: :not_found
  rescue_from StandardError, with: :internal_server_error unless Rails.env.development?

  private

  def not_found
    render "errors/not_found", status: :not_found
  end

  def internal_server_error
    render "errors/internal_server_error", status: :internal_server_error
  end
end
