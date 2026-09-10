# frozen_string_literal: true

require "test_helper"

module Admin
  # Security: the admin panel must never fall back to a default password.
  # If ADMIN_PASSWORD is unset, every request must be rejected (fail closed).
  class AdminAuthHardeningTest < ActionDispatch::IntegrationTest
    test "rejects default admin/admin credentials when ADMIN_PASSWORD is unset" do
      with_admin_password(nil) do
        headers = {
          "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", "admin")
        }
        get admin_root_path, headers: headers
        assert_response :unauthorized
      end
    end

    test "accepts the configured ADMIN_PASSWORD" do
      with_admin_password("s3cret") do
        headers = {
          "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", "s3cret")
        }
        get admin_root_path, headers: headers
        assert_response :success
      end
    end

    test "rejects wrong password even when ADMIN_PASSWORD is set" do
      with_admin_password("s3cret") do
        headers = {
          "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", "wrong")
        }
        get admin_root_path, headers: headers
        assert_response :unauthorized
      end
    end

    private

    def with_admin_password(value)
      original = ENV["ADMIN_PASSWORD"]
      if value.nil?
        ENV.delete("ADMIN_PASSWORD")
      else
        ENV["ADMIN_PASSWORD"] = value
      end
      yield
    ensure
      if original.nil?
        ENV.delete("ADMIN_PASSWORD")
      else
        ENV["ADMIN_PASSWORD"] = original
      end
    end
  end
end
