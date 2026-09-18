require "test_helper"

module Admin
  class PreviousTasksControllerTest < ActionDispatch::IntegrationTest
    include AdminCrudTests

    def setup
      @task = create_task("Test Task", "TT")
      @task2 = create_task("Test Task Two", "TT2")
      @requirement = Requirement.first || Requirement.create!(task_id: @task.id, player_level: 1)
      @resource = PreviousTask.first || PreviousTask.create!(
        requirement_id: @requirement.id, task_id: @task2.id, task_name: "Test Task"
      )
    end

    admin_crud_tests model: PreviousTask, heading: "Previous Tasks",
                     create_attrs: -> { { requirement_id: @requirement.id, task_id: @task.id, task_name: "New Task" } },
                     update_attrs: -> { { task_name: "Updated Task" } },
                     destroy_attrs: -> { { requirement_id: @requirement.id, task_id: @task.id, task_name: "Test" } }
  end
end
