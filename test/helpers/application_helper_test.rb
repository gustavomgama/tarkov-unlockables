# frozen_string_literal: true

require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  include ApplicationHelper

  test "data_freshness is the newest item or task timestamp" do
    item = create_item("Freshness Item", short_name: "FI")
    task = create_task("Freshness Task", "freshness-task", given_by: "Prapor")

    assert_equal [ item.updated_at, task.updated_at ].max, data_freshness
  ensure
    item&.destroy
    task&.destroy
  end

  test "data_freshness follows the newest task when only tasks changed" do
    task = create_task("Freshness Only Task", "freshness-only-task", given_by: "Prapor")

    assert_equal task.updated_at, data_freshness
  ensure
    task&.destroy
  end
end
