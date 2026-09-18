# frozen_string_literal: true

require "test_helper"

class ItemsIndexQueryBudgetTest < ActionDispatch::IntegrationTest
  include QueryCounting

  # The filter dropdowns must be built with grouped queries, not one count
  # per option. With N calibers the old implementation fired ~3N queries
  # (plus one per category); grouped queries fire a constant handful.
  test "items index renders within a sane query budget" do
    10.times do |i|
      create_item("Budget Ammo #{i}", klass: Item::Ammo, data: { "caliber" => "9x#{i}mm" })
      create_item("Budget Cat #{i}", categories: [ "budget_cat_#{i}" ])
    end

    query_count = count_queries { get items_url }

    assert_response :success
    assert_operator query_count, :<=, 30,
                    "items#index fired #{query_count} queries — dropdown counts must be grouped, not per-option"
  ensure
    Item.where("bsg_id LIKE 'qb-%'").delete_all
  end
end
