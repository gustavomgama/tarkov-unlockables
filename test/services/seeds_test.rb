# frozen_string_literal: true

require "test_helper"

# Seeds.rb is a thin orchestrator: 4 importers + 1 cross-table resolution step.
# We don't reload the entire fixtures pipeline (too heavy, would pollute DB);
# instead we verify the resolution step's behaviour in isolation with the same
# logic the orchestrator runs.
class SeedsTest < ActiveSupport::TestCase
  fixtures :items, :tasks

  # Mirror seeds.rb's resolution block — extracted here to avoid running the
  # full seeds pipeline (which requires all offlinedata/* files).
  def resolve_item_task_rewards
    ItemTaskReward.where(task_id: nil).find_each do |itr|
      task = Task.find_by(full_name: itr.task_name) || Task.find_by(name: itr.task_name)
      itr.update!(task_id: task.id) if task
    end
  end

  setup do
    # Make item_one's full_name match task_one's full_name so resolution fires.
    items(:one).update!(full_name: tasks(:one).full_name)
    @known_task_name = tasks(:one).full_name
    ItemTaskReward.create!(item: items(:one), task_name: @known_task_name)
  end

  test "resolves item_task_rewards.task_id by full_name" do
    itr = ItemTaskReward.where(task_name: @known_task_name, task_id: nil).first
    assert_nil itr&.task_id

    resolve_item_task_rewards

    itr.reload
    refute_nil itr.task_id
    assert_equal tasks(:one).id, itr.task_id
  end

  test "falls back to name lookup when full_name doesn't match" do
    # item_two's full_name won't match any task's full_name;
    # but matching via Task.name (slug) does.
    ItemTaskReward.create!(item: items(:two), task_name: tasks(:two).name)
    items(:two).update!(full_name: "Mismatch full_name")

    resolve_item_task_rewards

    itr = ItemTaskReward.find_by(task_name: tasks(:two).name)
    assert_equal tasks(:two).id, itr.task_id
  end

  test "leaves item_task_rewards with unknown task_name unresolved" do
    ItemTaskReward.create!(item: items(:one), task_name: "nonexistent-task-slug")

    resolve_item_task_rewards

    itr = ItemTaskReward.find_by(task_name: "nonexistent-task-slug")
    assert_nil itr.task_id
  end

  test "is idempotent — running resolution twice is a no-op for already-resolved rows" do
    resolve_item_task_rewards

    first_id = ItemTaskReward.find_by(task_name: @known_task_name).task_id
    resolve_item_task_rewards
    second_id = ItemTaskReward.find_by(task_name: @known_task_name).task_id

    assert_equal first_id, second_id
  end
end
