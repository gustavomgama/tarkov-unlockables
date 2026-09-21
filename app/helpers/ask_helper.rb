# frozen_string_literal: true

module AskHelper
  TARGET_NAMES = {
    "item" => "item page",
    "station" => "hideout page",
    "trader" => "trader page",
    "task" => "task page"
  }.freeze

  # The page that holds the full answer for whatever the question resolved to.
  def ask_target_path(answer)
    case answer.kind
    when "item" then item_path(answer.record)
    when "station" then station_path(answer.record.slug)
    when "trader" then trader_path(answer.record.slug)
    when "task" then task_path(answer.record)
    end
  end

  def ask_target_name(answer)
    TARGET_NAMES.fetch(answer.kind) { "page" }
  end
end
