# frozen_string_literal: true

module Importers
  # The item index imports item_task_rewards with only a task_name (the task
  # graph is not loaded yet). Once it is, this backfills task_id, matching the
  # full name first and falling back to the slug-style name.
  #
  # Idempotent: rows that already have a task_id are not revisited.
  class ItemTaskRewardResolver
    def self.call
      new.call
    end

    def call
      ItemTaskReward.where(task_id: nil).find_each do |reward|
        name = reward.task_name
        task = Task.find_by(full_name: name) || Task.find_by(name: name)
        reward.update!(task_id: task.id) if task
      end
    end
  end
end
