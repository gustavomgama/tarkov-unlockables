require "test_helper"

# Goldiloader auto-preloads in dev/test only, so a missing `includes` stays
# invisible locally and turns into an N+1 in production. These budgets run
# with Goldiloader off to catch that.
class ShowQueryBudgetTest < ActionDispatch::IntegrationTest
  fixtures :all

  def count_queries
    count = 0
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |_n, _s, _f, _i, payload|
      unless payload[:name].in?([ "SCHEMA", "TRANSACTION" ]) || payload[:sql].start_with?("SAVEPOINT", "RELEASE", "ROLLBACK")
        count += 1
      end
    end
    goldiloader = Goldiloader.enabled?
    Goldiloader.enabled = false
    yield
    count
  ensure
    Goldiloader.enabled = goldiloader
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  # Budget history:
  #   15 → 18  the layout states when the data last changed, which costs two
  #            MAX() scans on a cache miss. Cached for an hour, so a real
  #            request pays nothing.
  test "tasks#show query budget" do
    # Resolve route + fixtures before counting.
    url = task_url(tasks(:one))
    queries = count_queries { get url }
    assert_response :success
    assert_operator queries, :<=, 18, "tasks#show fired #{queries} queries"
  end

  # Budget history:
  #   22 → 28  the page gained "Used in" (the barters and crafts this item
  #            feeds), which preloads two more nested graphs. Flat, not an
  #            N+1: an item with one requirement row costs 18 queries, one
  #            with three costs 17, because the preloads batch.
  #   28 → 30  two MAX() scans for the layout's data-freshness line, cached
  #            hourly (see ApplicationHelper#data_freshness).
  #   30 → 32  barter and craft recipes (inputs, tools, duration) preload two
  #            more nested graphs. Also flat: one query per graph regardless
  #            of how many requirement rows an offer has.
  test "items#show query budget" do
    url = item_url(items(:one))
    queries = count_queries { get url }
    assert_response :success
    assert_operator queries, :<=, 32, "items#show fired #{queries} queries"
  end
end
