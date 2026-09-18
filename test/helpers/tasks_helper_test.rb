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

  # The reward kinds that live in `rewards.data` instead of a table, one line
  # each. Every branch of reward_data_line is exercised here.
  test "reward_data_groups renders each data-backed reward kind" do
    reward = create_task("Data Reward Task").rewards.create!(
      reward_type: "finish_rewards",
      data: {
        "trader_standing" => [ { "trader_slug" => "prapor", "standing" => 0.25 } ],
        "skill_level_reward" => [ { "skill" => "Strength", "level" => 3 } ],
        "trader_unlock" => [ { "trader_name" => "Jaeger" } ],
        "trader_dialogue_unlock" => [ { "trader_slug" => "mechanic" } ],
        "achievement" => [ { "name" => "Test Achievement" } ],
        "customization" => [ { "customizationType" => "clothing" } ]
      }
    )

    groups = reward_data_groups(reward).to_h { |label, _badge, lines| [ label, lines ] }

    assert_equal [ "Prapor +0.25 rep" ], groups["Standing"]
    assert_equal [ "Strength level 3" ], groups["Skill"]
    assert_equal [ "Jaeger" ], groups["Trader unlock"]
    assert_equal [ "Mechanic" ], groups["Dialogue"]
    assert_equal [ "Test Achievement" ], groups["Achievement"]
    assert_equal [ "Clothing" ], groups["Customization"]
  end

  test "reward_data_groups skips a kind with no rows" do
    reward = create_task("No Data Reward Task").rewards.create!(reward_type: "finish_rewards", data: {})

    assert_equal [], reward_data_groups(reward)
  end

  test "reward_data_groups treats non-hash data as empty" do
    reward = create_task("Bad Data Reward Task").rewards.create!(reward_type: "finish_rewards")
    reward.update_column(:data, "not a hash")

    assert_equal [], reward_data_groups(reward)
  end

  test "reward_data_line falls back to the row's values" do
    assert_equal "a b", reward_data_line("something_new", { "x" => "a", "y" => "b" })
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
