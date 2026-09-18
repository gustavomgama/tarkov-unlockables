require "test_helper"

module Admin
  class TasksControllerTest < ActionDispatch::IntegrationTest
    include AdminCrudTests

    def setup
      @task = create_task("Test Task", "TT", given_by: "Prapor")
      @resource = @task
    end

    def teardown
      @task.destroy if @task
    end

    admin_crud_tests model: Task, heading: "Tasks", display_count: true,
                     index_columns: [ "ID", "BSG ID", "Name", "Given By", "Kappa" ],
                     index_data_fields: %i[bsg_id name],
                     show_fields: [ [ "BSG ID", :bsg_id ], [ nil, :name ], [ nil, :given_by ] ],
                     edit_fields: %i[bsg_id name],
                     create_attrs: lambda {
                       { bsg_id: "new#{SecureRandom.hex(4)}", full_name: "New Task", name: "NT", given_by: "Prapor" }
                     },
                     update_attrs: -> { { name: "Updated Name" } },
                     destroy_attrs: lambda {
                       { bsg_id: "del#{SecureRandom.hex(4)}", full_name: "Delete Me", name: "DM", given_by: "Prapor" }
                     }

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

    test "missing task renders the admin 404 page" do
      get_auth admin_task_url(id: 999_999_999)

      assert_response :not_found
      assert_select "h1", "404"
    end
  end
end
