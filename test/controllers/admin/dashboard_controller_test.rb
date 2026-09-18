require "test_helper"

module Admin
  class DashboardControllerTest < ActionDispatch::IntegrationTest
    include AdminRequestAuth

    test "dashboard lists every model with its count and a manage link" do
      get_auth admin_root_path

      assert_response :success
      assert_match /Dashboard/i, response.body
      assert_match /Items/i, response.body
      assert_match /Tasks/i, response.body
      # Fixture counts, so the numbers are the real ones.
      assert_match /Items.*2/m, response.body
      assert_match /Tasks.*2/m, response.body
      assert_match /Manage/, response.body
    end

    test "dashboard requires authentication" do
      get admin_root_path

      assert_response :unauthorized
    end
  end
end
