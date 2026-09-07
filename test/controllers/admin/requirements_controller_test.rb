require "test_helper"

module Admin
  class RequirementsControllerTest < ActionDispatch::IntegrationTest
    def setup
      @resource = Requirement.first || Requirement.create!(task_id: 1, player_level: 1)
      @admin_password = ENV.fetch("ADMIN_PASSWORD") { "admin" }
      @admin_auth = {
        "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", @admin_password)
      }
    end

    def teardown
    end

    def get_auth(url, **kwargs)
      get url, **kwargs.merge(headers: @admin_auth)
    end

    def post_auth(url, **kwargs)
      post url, **kwargs.merge(headers: @admin_auth)
    end

    def patch_auth(url, **kwargs)
      patch url, **kwargs.merge(headers: @admin_auth)
    end

    def delete_auth(url, **kwargs)
      delete url, **kwargs.merge(headers: @admin_auth)
    end

    test "get index with auth" do
      get_auth admin_requirements_path
      assert_response :success
      assert_select "h1", /Requirements/i
    end

    test "index has new button" do
      get_auth admin_requirements_path
      assert_response :success
      assert_match /New Requirement/i, response.body
    end

    test "get show with auth" do
      get_auth admin_requirement_path(@resource)
      assert_response :success
    end

    test "show has edit and delete buttons" do
      get_auth admin_requirement_path(@resource)
      assert_response :success
      assert_match /Edit/i, response.body
      assert_match /Delete/i, response.body
    end

    test "get new with auth" do
      get_auth new_admin_requirement_path
      assert_response :success
      assert_match /New Requirement/i, response.body
    end

    test "create with valid params" do
      assert_difference("Requirement.count") do
        post_auth admin_requirements_path, params: { requirement: { task_id: 1, player_level: 10 } }
      end
      assert_redirected_to admin_requirement_path(Requirement.last)
    end

    test "get edit with auth" do
      get_auth edit_admin_requirement_path(@resource)
      assert_response :success
      assert_match /Edit Requirement/i, response.body
    end

    test "update with valid params" do
      patch_auth admin_requirement_path(@resource), params: { requirement: { player_level: 20 } }
      assert_redirected_to admin_requirement_path(@resource)
    end

    test "destroy redirects to index" do
      new_resource = Requirement.create!(task_id: 1, player_level: 1)
      delete_auth admin_requirement_path(new_resource)
      assert_redirected_to admin_requirements_path
    end

    test "index requires authentication" do
      get admin_requirements_path
      assert_response :unauthorized
    end

    test "show requires authentication" do
      get admin_requirement_path(@resource)
      assert_response :unauthorized
    end
  end
end
