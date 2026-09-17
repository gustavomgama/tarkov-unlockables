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

  # The two new browse pages. Both preload their one nested graph, so the
  # budget is small and flat: it only moves if a list starts querying per row.
  test "traders#show query budget" do
    trader = Trader.create!(bsg_id: "qb-#{SecureRandom.hex(4)}", slug: "qb-#{SecureRandom.hex(4)}",
                            name: "Budget Trader", currency: "RUB")
    trader.trader_levels.create!(level: 1)
    item = Item.create!(bsg_id: "qb-i-#{SecureRandom.hex(4)}", full_name: "Budget Item", short_name: "BI")
    item.item_currencies.create!(trader: "Budget Trader", currency: "RUB", min_trader_level: 1)

    url = trader_url(trader.slug)
    queries = count_queries { get url }
    assert_response :success
    assert_operator queries, :<=, 8, "traders#show fired #{queries} queries"
  ensure
    item&.item_currencies&.destroy_all
    item&.destroy
    trader&.destroy
  end

  test "stations#show query budget" do
    station = HideoutStation.create!(bsg_id: "qb-#{SecureRandom.hex(4)}", slug: "qb-#{SecureRandom.hex(4)}",
                                     name: "Budget Station")
    level = station.hideout_levels.create!(level: 1)
    item = Item.create!(bsg_id: "qb-s-#{SecureRandom.hex(4)}", full_name: "Budget Input", short_name: "BIn")
    level.hideout_item_requirements.create!(item: item, item_name: item.full_name, count: 1)

    url = station_url(station.slug)
    queries = count_queries { get url }
    assert_response :success
    assert_operator queries, :<=, 8, "stations#show fired #{queries} queries"
  ensure
    station&.destroy
    item&.destroy
  end

  # The reference charts load one item type and render jsonb, so they stay
  # flat regardless of how many rows the type has.
  test "ammo#index query budget" do
    queries = count_queries { get ammo_url }
    assert_response :success
    assert_operator queries, :<=, 8, "ammo#index fired #{queries} queries"
  end

  test "armor#index query budget" do
    queries = count_queries { get armor_url }
    assert_response :success
    assert_operator queries, :<=, 8, "armor#index fired #{queries} queries"
  end

  test "keys#index query budget" do
    queries = count_queries { get keys_url }
    assert_response :success
    assert_operator queries, :<=, 8, "keys#index fired #{queries} queries"
  end
end
