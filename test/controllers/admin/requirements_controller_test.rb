require "test_helper"

module Admin
  class RequirementsControllerTest < ActionDispatch::IntegrationTest
    include AdminCrudTests

    def setup
      @task = create_task("Test Task", "TT")
      @resource = Requirement.first || Requirement.create!(task_id: @task.id, player_level: 1)
    end

    admin_crud_tests model: Requirement, heading: "Requirements",
                     create_attrs: -> { { task_id: @task.id, player_level: 10 } },
                     update_attrs: -> { { player_level: 20 } },
                     destroy_attrs: -> { { task_id: @task.id, player_level: 1 } }
  end
end
