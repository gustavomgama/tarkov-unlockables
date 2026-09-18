# Shared setup for the unlock admin CRUD tests: a task, an item, a reward and
# the unlock resource (craft/offer) plus the create/update/destroy attrs the
# AdminCrudTests DSL reads.
module AdminUnlockSetup
  def setup_unlock_resources(model, resource_attrs:, create_attrs:, destroy_attrs:)
    @task = create_task("Test Task", "TT")
    @item = create_item("Test Item")
    @reward = Reward.first || Reward.create!(task_id: @task.id, reward_type: "Item")
    @resource = model.first || model.create!(
      { reward_id: @reward.id, item_id: @item.id, item_name: "Test Item" }.merge(resource_attrs)
    )
    @create_attrs = { reward_id: @reward.id, item_id: @item.id, item_name: "New #{model.name}" }.merge(create_attrs)
    @update_attrs = { item_name: "Updated Item" }
    @destroy_attrs = { reward_id: @reward.id, item_id: @item.id, item_name: "Test" }.merge(destroy_attrs)
  end
end
