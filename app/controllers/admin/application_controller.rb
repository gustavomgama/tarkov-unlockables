class Admin::ApplicationController < ApplicationController
  # Rails has no lockout for HTTP Basic, so a wrong password would otherwise be
  # free to retry forever. Count only *failed* logins per IP — a successful one
  # clears the counter — and answer 429 once the window's attempts are used up.
  # The store is dedicated so the limiter also works in the test env, where the
  # global cache is a null_store, and so it can be reset between tests.
  FAILED_LOGIN_LIMIT = 10
  FAILED_LOGIN_WINDOW = 5.minutes
  FAILED_LOGIN_STORE = ActiveSupport::Cache::MemoryStore.new(size: 1.megabyte)

  before_action :authenticate

  layout "admin/layouts/application"

  private

  def authenticate
    return head :too_many_requests if failed_login_limit_reached?

    # Not `authenticate_or_request_with_http_basic`: that returns the rendered
    # challenge (truthy) on failure, so it cannot be used as a boolean here.
    if authenticate_with_http_basic { |username, password| valid_admin_credentials?(username, password) }
      FAILED_LOGIN_STORE.delete(failed_login_key)
    else
      record_failed_login
      request_http_basic_authentication
    end
  end

  def valid_admin_credentials?(username, password)
    # Fail closed: no default password. If ADMIN_PASSWORD is unset, every
    # request is rejected. Production boot also enforces this (see
    # config/initializers/admin_password_check.rb).
    expected = ENV["ADMIN_PASSWORD"]
    expected.present? &&
      ActiveSupport::SecurityUtils.secure_compare(username.to_s, "admin") &&
      ActiveSupport::SecurityUtils.secure_compare(password.to_s, expected)
  end

  def failed_login_key
    "admin/failed-logins/#{request.remote_ip}"
  end

  def failed_login_limit_reached?
    FAILED_LOGIN_STORE.read(failed_login_key).to_i >= FAILED_LOGIN_LIMIT
  end

  def record_failed_login
    FAILED_LOGIN_STORE.increment(failed_login_key, 1, expires_in: FAILED_LOGIN_WINDOW)
  end

  def not_found
    render "errors/not_found", status: :not_found, layout: "admin/layouts/application"
  end

  def internal_server_error
    render "errors/internal_server_error", status: :internal_server_error, layout: "admin/layouts/application"
  end
end
