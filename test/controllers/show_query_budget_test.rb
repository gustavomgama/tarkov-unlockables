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

  test "tasks#show query budget" do
    # Resolve route + fixtures before counting.
    url = task_url(tasks(:one))
    queries = count_queries { get url }
    assert_response :success
    assert_operator queries, :<=, 15, "tasks#show fired #{queries} queries"
  end

  test "items#show query budget" do
    url = item_url(items(:one))
    queries = count_queries { get url }
    assert_response :success
    assert_operator queries, :<=, 22, "items#show fired #{queries} queries"
  end
end
