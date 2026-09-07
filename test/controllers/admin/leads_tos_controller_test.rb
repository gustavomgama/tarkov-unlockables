require "test_helper"

module Admin
  class LeadsTosControllerTest < ActionDispatch::IntegrationTest
    def setup
      @task = Task.first || Task.create!(bsg_id: "test#{SecureRandom.hex(4)}", full_name: "Test Task", name: "TT")
      @resource = LeadsTo.create!(task_id: @task.id, follow_up_task_id: @task.id + 1, follow_up_task_name: "Test Follow Up")
      @admin_password = ENV.fetch("ADMIN_PASSWORD") { "admin" }
      @admin_auth = {
        "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", @admin_password)
      }
    end

    def teardown
      @resource.destroy if @resource
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
      get_auth admin_leads_tos_path
      assert_response :success
      assert_select "h1", /Leads To/i
    end

    test "index displays count" do
      get_auth admin_leads_tos_path
      assert_response :success
      assert_match /\(#{LeadsTo.count}\)/, response.body
    end

    test "index has new button" do
      get_auth admin_leads_tos_path
      assert_response :success
      assert_match /New LeadsTo/i, response.body
    end

    test "get show with auth" do
      get_auth admin_leads_to_path(@resource)
      assert_response :success
    end

    test "show has edit and delete buttons" do
      get_auth admin_leads_to_path(@resource)
      assert_response :success
      assert_match /Edit/i, response.body
      assert_match /Delete/i, response.body
    end

    test "get new with auth" do
      get_auth new_admin_leads_to_path
      assert_response :success
      assert_match /New LeadsTo/i, response.body
    end

    test "create with valid params" do
      assert_difference("LeadsTo.count") do
        post_auth admin_leads_tos_path,
                      params: { leads_to: { task_id: @task.id, follow_up_task_id: @task.id + 2, follow_up_task_name: "New Follow Up" } }
      end
      assert_redirected_to admin_leads_to_path(LeadsTo.last)
    end

    test "get edit with auth" do
      get_auth edit_admin_leads_to_path(@resource)
      assert_response :success
      assert_match /Edit LeadsTo/i, response.body
    end

    test "update with valid params" do
      patch_auth admin_leads_to_path(@resource),
                     params: { leads_to: { follow_up_task_name: "Updated Name" } }
      assert_redirected_to admin_leads_to_path(@resource)
    end

    test "destroy redirects to index" do
      new_resource = LeadsTo.create!(task_id: @task.id, follow_up_task_id: @task.id + 3, follow_up_task_name: "Test")
      delete_auth admin_leads_to_path(new_resource)
      assert_redirected_to admin_leads_tos_path
    end

    test "index requires authentication" do
      get admin_leads_tos_path
      assert_response :unauthorized
    end

    test "show requires authentication" do
      get admin_leads_to_path(@resource)
      assert_response :unauthorized
    end
  end
end
