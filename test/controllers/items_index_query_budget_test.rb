# frozen_string_literal: true

require "test_helper"

class ItemsIndexQueryBudgetTest < ActionDispatch::IntegrationTest
  # The filter dropdowns must be built with grouped queries, not one count
  # per option. With N calibers the old implementation fired ~3N queries
  # (plus one per category); grouped queries fire a constant handful.
  test "items index renders within a sane query budget" do
    10.times do |i|
      Item::Ammo.create!(
        bsg_id: "qb-cal-#{i}-#{SecureRandom.hex(4)}",
        full_name: "Budget Ammo #{i}",
        short_name: "BA#{i}",
        data: { "caliber" => "9x#{i}mm" }
      )
    end
    10.times do |i|
      Item.create!(
        bsg_id: "qb-cat-#{i}-#{SecureRandom.hex(4)}",
        full_name: "Budget Cat #{i}",
        short_name: "BC#{i}",
        categories: [ "budget_cat_#{i}" ]
      )
    end

    query_count = 0
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |_name, _start, _finish, _id, payload|
      unless payload[:name].in?([ "SCHEMA", "TRANSACTION" ]) || payload[:sql].start_with?("SAVEPOINT", "RELEASE", "ROLLBACK")
        query_count += 1
      end
    end

    get items_url
    assert_response :success
    assert_operator query_count, :<=, 30,
                    "items#index fired #{query_count} queries — dropdown counts must be grouped, not per-option"
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
    Item.where("bsg_id LIKE 'qb-%'").delete_all
  end
end
