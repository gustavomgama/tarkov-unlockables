require "test_helper"

module Admin
  class BarterUnlocksControllerTest < ActionDispatch::IntegrationTest
    include AdminCrudTests

    def setup
      @task = create_task("Test Task", "TT")
      @item = create_item("Test Item")
      @reward = Reward.first || Reward.create!(task_id: @task.id, reward_type: "Item")
      @resource = BarterUnlock.first || BarterUnlock.create!(
        reward_id: @reward.id, item_id: @item.id, item_name: "Test Item"
      )
    end

    admin_crud_tests model: BarterUnlock, heading: "Barter Unlocks", item_select: true,
                     create_attrs: -> { { reward_id: @reward.id, item_id: @item.id, item_name: "New Barter Item" } },
                     update_attrs: -> { { item_name: "Updated Item" } },
                     destroy_attrs: -> { { reward_id: @reward.id, item_id: @item.id, item_name: "Test" } }
  end
end
