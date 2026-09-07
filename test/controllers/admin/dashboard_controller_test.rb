require "test_helper"

module Admin
  class DashboardControllerTest < ActionDispatch::IntegrationTest
    def setup
      @admin_password = ENV.fetch("ADMIN_PASSWORD") { "admin" }
      @admin_auth = {
        "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", @admin_password)
      }
    end

    def get_auth(url, **kwargs)
      get url, **kwargs.merge(headers: @admin_auth)
    end

    test "dashboard index displays all model counts" do
      get_auth admin_root_path

      assert_response :success
      assert_match /Dashboard/i, response.body
      assert_match /Items/i, response.body
      assert_match /Tasks/i, response.body
      assert_match /Properties/i, response.body
    end

    test "dashboard shows correct counts" do
      get_auth admin_root_path

      assert_response :success
      assert_match /Items.*0/m, response.body
      assert_match /Tasks.*0/m, response.body
    end

    test "dashboard has manage links for each model" do
      get_auth admin_root_path

      assert_response :success
      assert_match /Manage/, response.body
    end

    test "dashboard requires authentication" do
      get admin_root_path

      assert_response :unauthorized
    end
  end
end
