require "test_helper"

module Admin
  class RewardsControllerTest < ActionDispatch::IntegrationTest
    include AdminCrudTests

    def setup
      @task = create_task("Test Task", "TT")
      @resource = Reward.first || Reward.create!(task_id: @task.id, reward_type: "Item")
    end

    admin_crud_tests model: Reward, heading: "Rewards",
                     create_attrs: -> { { task_id: @task.id, reward_type: "Experience" } },
                     update_attrs: -> { { reward_type: "Cash" } },
                     destroy_attrs: -> { { task_id: @task.id, reward_type: "Item" } }
  end
end
