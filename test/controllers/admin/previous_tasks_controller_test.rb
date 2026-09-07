require "test_helper"

module Admin
  class PreviousTasksControllerTest < ActionDispatch::IntegrationTest
    def setup
      @task = Task.create!(bsg_id: "task#{SecureRandom.hex(4)}", full_name: "Test Task", name: "TT")
      @task2 = Task.create!(bsg_id: "task#{SecureRandom.hex(4)}", full_name: "Test Task Two", name: "TT2")
      @requirement = Requirement.first || Requirement.create!(task_id: @task.id, player_level: 1)
      @resource = PreviousTask.first || PreviousTask.create!(requirement_id: @requirement.id, task_id: @task2.id, task_name: "Test Task")
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
      get_auth admin_previous_tasks_path
      assert_response :success
      assert_select "h1", /Previous Tasks/i
    end

    test "index has new button" do
      get_auth admin_previous_tasks_path
      assert_response :success
      assert_match /New Previous Task/i, response.body
    end

    test "get show with auth" do
      get_auth admin_previous_task_path(@resource)
      assert_response :success
    end

    test "show has edit and delete buttons" do
      get_auth admin_previous_task_path(@resource)
      assert_response :success
      assert_match /Edit/i, response.body
      assert_match /Delete/i, response.body
    end

    test "get new with auth" do
      get_auth new_admin_previous_task_path
      assert_response :success
      assert_match /New Previous Task/i, response.body
    end

    test "create with valid params" do
      assert_difference("PreviousTask.count") do
        post_auth admin_previous_tasks_path, params: { previous_task: { requirement_id: @requirement.id, task_id: @task.id, task_name: "New Task" } }
      end
      assert_redirected_to admin_previous_task_path(PreviousTask.last)
    end

    test "get edit with auth" do
      get_auth edit_admin_previous_task_path(@resource)
      assert_response :success
      assert_match /Edit Previous Task/i, response.body
    end

    test "update with valid params" do
      patch_auth admin_previous_task_path(@resource), params: { previous_task: { task_name: "Updated Task" } }
      assert_redirected_to admin_previous_task_path(@resource)
    end

    test "destroy redirects to index" do
      new_resource = PreviousTask.create!(requirement_id: @requirement.id, task_id: @task.id, task_name: "Test")
      delete_auth admin_previous_task_path(new_resource)
      assert_redirected_to admin_previous_tasks_path
    end

    test "index requires authentication" do
      get admin_previous_tasks_path
      assert_response :unauthorized
    end

    test "show requires authentication" do
      get admin_previous_task_path(@resource)
      assert_response :unauthorized
    end
  end
end
