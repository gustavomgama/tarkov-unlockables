require "test_helper"

# TasksHelper is presentation-only, so these call the helpers directly instead
# of rendering a page for each branch.
class TasksHelperTest < ActionView::TestCase
  test "reward_groups skips a reward with nothing attached" do
    reward = create_task("Empty Reward Task").rewards.create!(reward_type: "Item")

    assert_equal [], reward_groups(reward)
  end

  test "reward_groups labels a populated reward with its badge" do
    reward = create_task("Populated Task").rewards.create!(reward_type: "Item")
    reward.loose_items.create!(item_name: "Salewa")

    label, rows, badge = reward_groups(reward).first

    assert_equal "Items", label
    assert_equal 1, rows.size
    assert badge
  end

  test "reward_label names money rows as currency" do
    assert_equal "Currency", reward_label("Items", LooseItem.new(item_name: "5000 Roubles"))
    assert_equal "Items", reward_label("Items", LooseItem.new(item_name: "Salewa"))
  end

  test "reward_label leaves the other group labels alone" do
    assert_equal "Barter", reward_label("Barter", LooseItem.new(item_name: "5000 Roubles"))
  end

  test "trader_requirement_label omits an empty trader name" do
    assert_equal "LL4", trader_requirement_label({ "trader_name" => "", "trader_level" => "4" })
    assert_equal "Peacekeeper LL3",
                 trader_requirement_label({ "trader_name" => "peacekeeper", "trader_level" => "3" })
  end

  test "trader_requirements keeps only hash entries" do
    requirement = Requirement.new(trader_level: [ { "trader_name" => "Prapor" }, "junk", nil ])

    assert_equal [ { "trader_name" => "Prapor" } ], trader_requirements(requirement)
  end
end
