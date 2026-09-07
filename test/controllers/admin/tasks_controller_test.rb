require "test_helper"

module Admin
  class TasksControllerTest < ActionDispatch::IntegrationTest
    def setup
      @task = Task.create!(bsg_id: "test#{SecureRandom.hex(4)}", full_name: "Test Task", name: "TT", given_by: "Prapor")
      @admin_password = ENV.fetch("ADMIN_PASSWORD") { "admin" }
      @admin_auth = {
        "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", @admin_password)
      }
    end

    def teardown
      @task.destroy if @task
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
      get_auth admin_tasks_url
      assert_response :success
      assert_select "h1", /Tasks/i
    end

    test "index displays count" do
      get_auth admin_tasks_url
      assert_response :success
      assert_match /\(#{Task.count}\)/, response.body
    end

    test "index has new button" do
      get_auth admin_tasks_url
      assert_response :success
      assert_match /New Task/i, response.body
    end

    test "index displays table headers" do
      get_auth admin_tasks_url
      assert_response :success
      assert_match /<th[^>]*>ID<\/th>/, response.body
      assert_match /<th[^>]*>BSG ID<\/th>/, response.body
      assert_match /<th[^>]*>Name<\/th>/, response.body
      assert_match /<th[^>]*>Given By<\/th>/, response.body
      assert_match /<th[^>]*>Kappa<\/th>/, response.body
    end

    test "index displays resource data" do
      get_auth admin_tasks_url
      assert_response :success
      assert_match @task.bsg_id, response.body
      assert_match @task.name, response.body
    end

    test "get show with auth" do
      get_auth admin_task_url(@task)
      assert_response :success
      assert_match /Test Task/, response.body
    end

    test "show displays all fields" do
      get_auth admin_task_url(@task)
      assert_response :success
      assert_match /BSG ID/, response.body
      assert_match @task.bsg_id, response.body
      assert_match @task.name, response.body
      assert_match @task.given_by, response.body
    end

    test "show has edit and delete buttons" do
      get_auth admin_task_url(@task)
      assert_response :success
      assert_match /Edit/i, response.body
      assert_match /Delete/i, response.body
    end

    test "get new with auth" do
      get_auth new_admin_task_url
      assert_response :success
      assert_match /New Task/i, response.body
    end

    test "create with valid params" do
      bsg = "new#{SecureRandom.hex(4)}"
      assert_difference("Task.count") do
        post_auth admin_tasks_url, params: { task: { bsg_id: bsg, full_name: "New Task", name: "NT", given_by: "Prapor" } }
      end
      assert_redirected_to admin_task_url(Task.last)
    end

    test "get edit with auth" do
      get_auth edit_admin_task_url(@task)
      assert_response :success
      assert_match /Edit Task/i, response.body
    end

    test "edit form pre-populated with current values" do
      get_auth edit_admin_task_url(@task)
      assert_response :success
      assert_match /Edit Task/, response.body
      assert_match /name="task\[bsg_id\]"/, response.body
      assert_match /value="#{@task.bsg_id}"/, response.body
      assert_match /value="#{@task.name}"/, response.body
    end

    test "update with valid params" do
      patch_auth admin_task_url(@task), params: { task: { name: "Updated Name" } }
      assert_redirected_to admin_task_url(@task)
      @task.reload
      assert_equal "Updated Name", @task.name
    end

    test "update persists all fields when form is submitted" do
      new_name = "UpdatedTask_#{SecureRandom.hex(4)}"
      patch_auth admin_task_url(@task), params: {
        task: {
          bsg_id: @task.bsg_id,
          full_name: @task.full_name,
          name: new_name,
          wiki_link: @task.wiki_link,
          given_by: @task.given_by,
          kappa_required: @task.kappa_required,
          lightkeeper_required: @task.lightkeeper_required
        }
      }
      assert_redirected_to admin_task_url(@task)
      @task.reload
      assert_equal new_name, @task.name
    end

    test "destroy redirects to index" do
      new_task = Task.create!(bsg_id: "del#{SecureRandom.hex(4)}", full_name: "Delete Me", name: "DM", given_by: "Prapor")
      delete_auth admin_task_url(new_task)
      assert_redirected_to admin_tasks_url
    end

    test "index requires authentication" do
      get admin_tasks_url
      assert_response :unauthorized
    end

    test "show requires authentication" do
      get admin_task_url(@task)
      assert_response :unauthorized
    end

    test "new requires authentication" do
      get new_admin_task_url
      assert_response :unauthorized
    end

    test "create requires authentication" do
      post admin_tasks_url, params: { task: { bsg_id: "x", full_name: "X", name: "X" } }
      assert_response :unauthorized
    end

    test "edit requires authentication" do
      get edit_admin_task_url(@task)
      assert_response :unauthorized
    end

    test "update requires authentication" do
      patch admin_task_url(@task), params: { task: { name: "X" } }
      assert_response :unauthorized
    end

    test "destroy requires authentication" do
      delete admin_task_url(@task)
      assert_response :unauthorized
    end
  end
end
