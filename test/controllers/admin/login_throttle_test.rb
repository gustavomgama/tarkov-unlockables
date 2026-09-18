# frozen_string_literal: true

require "test_helper"

module Admin
  # HTTP Basic has no lockout of its own: without a throttle, a wrong password is
  # free to retry forever. Only failures count, and a good login resets them.
  class LoginThrottleTest < ActionDispatch::IntegrationTest
    include AdminRequestAuth

    WRONG_PASSWORD = {
      "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", "not-the-password")
    }.freeze

    def wrong_login
      get admin_items_url, headers: WRONG_PASSWORD
    end

    test "repeated failed logins are refused once the limit is reached" do
      Admin::ApplicationController::FAILED_LOGIN_LIMIT.times do
        wrong_login
        assert_response :unauthorized
      end

      wrong_login
      assert_response :too_many_requests
    end

    test "a successful login clears the failed attempts" do
      (Admin::ApplicationController::FAILED_LOGIN_LIMIT - 1).times { wrong_login }

      get_auth admin_items_url
      assert_response :success

      # The counter is gone, so failures start over instead of tripping the cap.
      wrong_login
      assert_response :unauthorized
    end

    test "the limit is per client ip" do
      Admin::ApplicationController::FAILED_LOGIN_LIMIT.times { wrong_login }
      wrong_login
      assert_response :too_many_requests

      wrong_login_from("203.0.113.7")
      assert_response :unauthorized
    end

    private

    # Rack's RemoteIp honours a forwarded address from a trusted proxy; the test
    # client is trusted, so this stands in for a second visitor.
    def wrong_login_from(ip)
      get admin_items_url, headers: WRONG_PASSWORD.merge("HTTP_X_FORWARDED_FOR" => ip)
    end
  end
end
