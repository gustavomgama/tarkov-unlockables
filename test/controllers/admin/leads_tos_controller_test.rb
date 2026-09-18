require "test_helper"

module Admin
  class LeadsTosControllerTest < ActionDispatch::IntegrationTest
    include AdminCrudTests

    def setup
      @task = Task.first || create_task("Test Task", "TT")
      @task2 = create_task("Test Task Two", "TT2")
      @resource = LeadsTo.create!(
        task_id: @task.id, follow_up_task_id: @task2.id, follow_up_task_name: "Test Follow Up"
      )
    end

    def teardown
      @resource.destroy if @resource
    end

    admin_crud_tests model: LeadsTo, heading: "Leads To", singular: "LeadsTo", display_count: true,
                     create_attrs: -> { { task_id: @task.id, follow_up_task_id: @task2.id, follow_up_task_name: "New Follow Up" } },
                     update_attrs: -> { { follow_up_task_name: "Updated Name" } },
                     destroy_attrs: -> { { task_id: @task.id, follow_up_task_id: @task2.id, follow_up_task_name: "Test" } }
  end
end
