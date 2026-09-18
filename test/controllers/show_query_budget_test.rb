require "test_helper"

# Goldiloader auto-preloads in dev/test only, so a missing `includes` stays
# invisible locally and turns into an N+1 in production. These budgets run
# with Goldiloader off to catch that.
#
# A ceiling alone does not prove there is no per-row query: the fixture rows
# are few, so a page could add a query per collection entry and still pass.
# The pages that render collections are therefore also asserted to stay flat
# as rows are added, and to actually render the rows they were given (a budget
# would otherwise pass if the new rows silently stopped being displayed).
class ShowQueryBudgetTest < ActionDispatch::IntegrationTest
  include QueryCounting
  include ItemsTestHelpers

  fixtures :all

  # Budget history:
  #   15 → 18  the layout states when the data last changed, which costs two
  #            MAX() scans on a cache miss. Cached for an hour, so a real
  #            request pays nothing.
  test "tasks#show query budget" do
    # Resolve route + fixtures before counting.
    assert_query_budget("tasks#show", task_url(tasks(:one)), 18)
  end

  # Budget history:
  #   22 → 28  the page gained "Used in" (the barters and crafts this item
  #            feeds), which preloads two more nested graphs. Flat, not an
  #            N+1: an item with one requirement row costs 18 queries, one
  #            with three costs 17, because the preloads batch.
  #   28 → 30  two MAX() scans for the layout's data-freshness line, cached
  #            hourly (see ApplicationHelper#data_freshness).
  test "items#show query budget" do
    assert_query_budget("items#show", item_url(items(:one)), 30)
  end

  test "tasks#index query budget" do
    assert_query_budget("tasks#index", tasks_url, 10)
  end

  # The listing renders the filter dropdowns, which are cached for an hour in
  # production but recomputed on every request here (the test env's cache store
  # is a null store), so this is the uncached worst case.
  test "items#index query budget" do
    assert_query_budget("items#index", items_url, 16)
  end

  test "items#index search query budget" do
    assert_query_budget("items#index search", items_url(q: "Test"), 16)
  end

  # The typeahead is a fragment, not a page: it must stay a single query.
  test "items#search query budget" do
    assert_query_budget("items#search", search_items_url(q: "Test"), 2)
  end

  test "tasks#chains query budget" do
    assert_query_budget("tasks#chains", chains_tasks_url, 10)
  end

  test "favorites#index query budget" do
    assert_query_budget("favorites#index", favorites_url, 6)
  end

  # Both listings must stay flat as the table grows, so the two are generated
  # from one description: [label, url helper, rendered row selector, factory,
  # name prefix]. Plain tuples rather than lambdas — flay ignores literals, so
  # two separate blocks (or two lambdas) score as duplication.
  LISTING_FLATNESS_CASES = [
    [ "items#index", :items_url, "td a", :create_item, "Budget Item" ],
    [ "tasks#index", :tasks_url, "a.task-row", :create_task, "Budget Task" ]
  ].freeze

  LISTING_FLATNESS_CASES.each do |label, url, shown, factory, prefix|
    test "#{label} stays flat as rows are added" do
      assert_flat(label, send(url), shown: shown) do
        10.times { |i| send(factory, "#{prefix} #{i}") }
      end
    end
  end

  # The "Used in" lists preload both unlock graphs.
  test "items#show stays flat as used-in rows are added" do
    item = items(:one)

    assert_flat("items#show", item_url(item), shown: ".srcrow") do
      task = create_task("Budget Used Task", "budget-used-task", given_by: "Prapor")
      reward = task.rewards.create!(reward_type: "finish_rewards")
      3.times do |i|
        build_used_in_unlock(reward, item, :barter,
                             requirement: { trader_name: "Prapor", trader_level: i + 7 }, count: i + 1)
      end
    end
  end

  # The leads panel preloads every follow-up task.
  test "tasks#show stays flat as leads are added" do
    task = tasks(:one)

    assert_flat("tasks#show", task_url(task), shown: "[aria-labelledby=leads-head] .chip") do
      3.times do |i|
        follow_up = create_task("Budget Lead #{i}", "budget-lead-#{i}")
        task.leads_tos.create!(follow_up_task: follow_up, follow_up_task_name: follow_up.name)
      end
    end
  end

  private

  # Adds records via the block, then asserts they render and cost no extra
  # queries.
  def assert_flat(label, url, shown:)
    get url
    rows_before = css_select(shown).size
    baseline = count_queries { get url }

    yield

    final = count_queries { get url }
    assert_select shown, minimum: rows_before + 1
    assert_operator final, :<=, baseline,
                    "#{label} went from #{baseline} to #{final} queries as rows were added"
  end
end
