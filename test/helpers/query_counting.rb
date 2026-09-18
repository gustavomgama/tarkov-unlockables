# Counts the SQL statements fired inside a block, ignoring schema/transaction
# noise. Goldiloader is disabled while counting so a missing `includes` cannot
# be masked by auto-preloading.
module QueryCounting
  def count_queries
    count = 0
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |_name, _start, _finish, _id, payload|
      next if payload[:name].in?([ "SCHEMA", "TRANSACTION" ])
      next if payload[:sql].start_with?("SAVEPOINT", "RELEASE", "ROLLBACK")

      count += 1
    end

    goldiloader = Goldiloader.enabled?
    Goldiloader.enabled = false
    yield
    count
  ensure
    Goldiloader.enabled = goldiloader
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  # Asserts the request at +url+ fires no more than +max+ queries.
  def assert_query_budget(label, url, max)
    queries = count_queries { get url }

    assert_response :success
    assert_operator queries, :<=, max, "#{label} fired #{queries} queries"
  end
end
