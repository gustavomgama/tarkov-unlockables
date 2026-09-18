# frozen_string_literal: true

require "test_helper"

module Admin
  # Security: the admin panel must never fall back to a default password.
  # If ADMIN_PASSWORD is unset, every request must be rejected (fail closed).
  class AdminAuthHardeningTest < ActionDispatch::IntegrationTest
    # [configured ADMIN_PASSWORD, supplied password, expected status]
    CREDENTIAL_CASES = [
      [ nil, "admin", :unauthorized ],
      [ "s3cret", "s3cret", :success ],
      [ "s3cret", "wrong", :unauthorized ]
    ].freeze

    test "admin panel enforces the configured password" do
      CREDENTIAL_CASES.each do |configured, supplied, expected|
        with_admin_password(configured) do
          headers = {
            "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", supplied)
          }
          get admin_root_path, headers: headers

          assert_response expected, "ADMIN_PASSWORD=#{configured.inspect}, supplied #{supplied.inspect}"
        end
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
