require "test_helper"

# LooseSearchable is included by ApplicationRecord, so every model can search.
# Only Item and Task have the trigram-indexed search_text column; the rest take
# the regexp_replace fallback.
class LooseSearchableTest < ActiveSupport::TestCase
  test "falls back to regexp_replace when the model has no search_text column" do
    task = create_task("Loose Search", "loose-search")
    task.rewards.create!(reward_type: "start_rewards")
    task.rewards.create!(reward_type: "finish_rewards")

    matches = Reward.loose_search("start", columns: %w[reward_type])

    assert_equal [ "start_rewards" ], matches.pluck(:reward_type)
  end

  test "a query that strips to nothing returns everything" do
    assert_equal Reward.count, Reward.loose_search("---", columns: %w[reward_type]).count
  end

  test "a blank query returns the whole relation" do
    assert_equal Reward.count, Reward.loose_search("", columns: %w[reward_type]).count
  end

  # The column name is interpolated into the SQL, so it is validated against the
  # model's own columns before it gets there (this is what replaced the Brakeman
  # ignore file).
  test "an unknown search column raises instead of reaching the query" do
    error = assert_raises(ArgumentError) do
      Reward.loose_search("start", columns: [ "reward_type; DROP TABLE items" ])
    end

    assert_match(/unknown search column/, error.message)
  end

  # The admin index calls this for every resource, including one that declares
  # no searchable columns; without the guard the empty WHERE would raise.
  test "no searchable columns returns the whole relation" do
    assert_equal Reward.count, Reward.loose_search("start", columns: []).count
    assert_equal Reward.count, Reward.loose_search("start", columns: nil).count
  end

  test "symbol column names are accepted like strings" do
    task = create_task("Symbol Search", "symbol-search")
    task.rewards.create!(reward_type: "start_rewards")

    assert_equal [ "start_rewards" ],
                 Reward.loose_search("start", columns: [ :reward_type ]).pluck(:reward_type)
  end
end
