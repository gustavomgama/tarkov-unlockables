class Admin::ApplicationController < ApplicationController
  before_action :authenticate

  layout "admin/layouts/application"

  private

  def authenticate
    authenticate_or_request_with_http_basic do |username, password|
      # Fail closed: no default password. If ADMIN_PASSWORD is unset, every
      # request is rejected. Production boot also enforces this (see
      # config/initializers/admin_password_check.rb).
      expected = ENV["ADMIN_PASSWORD"]
      expected.present? &&
        ActiveSupport::SecurityUtils.secure_compare(username.to_s, "admin") &&
        ActiveSupport::SecurityUtils.secure_compare(password.to_s, expected)
    end
  end

  def not_found
    render "errors/not_found", status: :not_found, layout: "admin/layouts/application"
  end

  def internal_server_error
    render "errors/internal_server_error", status: :internal_server_error, layout: "admin/layouts/application"
  end
end
