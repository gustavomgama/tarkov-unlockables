class Admin::ApplicationController < ApplicationController
  before_action :authenticate

  layout "admin/layouts/application"

  private

  def authenticate
    authenticate_or_request_with_http_basic do |username, password|
      username == "admin" && password == ENV.fetch("ADMIN_PASSWORD") { "admin" }
    end
  end
end
