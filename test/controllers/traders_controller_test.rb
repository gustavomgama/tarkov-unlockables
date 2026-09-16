require "test_helper"

class TradersControllerTest < ActionDispatch::IntegrationTest
  test "index lists traders with their level count" do
    trader = Trader.create!(bsg_id: "ix-#{SecureRandom.hex(4)}", slug: "ix-#{SecureRandom.hex(4)}",
                            name: "Index Trader", currency: "RUB")
    trader.trader_levels.create!(level: 1)

    get traders_url

    assert_response :success
    assert_match "Index Trader", response.body
    assert_select "a[href=?]", trader_path(trader.slug)
  ensure
    trader&.destroy
  end

  test "show lists loyalty levels and the offers per level" do
    trader = Trader.create!(bsg_id: "sh-#{SecureRandom.hex(4)}", slug: "sh-#{SecureRandom.hex(4)}",
                            name: "Show Trader", currency: "RUB", description: "A trader.")
    trader.trader_levels.create!(level: 1, required_player_level: 0, required_reputation: 0, pay_rate: 0.4)
    trader.trader_levels.create!(level: 2, required_player_level: 6, required_reputation: 0.7, pay_rate: 0.4)
    item = Item.create!(bsg_id: "tr-i-#{SecureRandom.hex(4)}", full_name: "Trader Widget", short_name: "TW")
    item.item_currencies.create!(trader: "Show Trader", currency: "RUB", min_trader_level: 2,
                                 price: 1234, buy_limit: 3)

    get trader_url(trader.slug)

    assert_response :success
    assert_select "h1", text: "Show Trader"
    assert_select "h2", text: "Loyalty levels"
    assert_select "th", text: "LL2"
    assert_select "h2", text: "LL2"
    assert_select "a[href=?]", item_path(item), text: "Trader Widget"
    assert_match "1,234 RUB", response.body
  ensure
    item&.item_currencies&.destroy_all
    item&.destroy
    trader&.destroy
  end

  test "show returns 404 for an unknown trader" do
    get trader_url("nope")
    assert_response :not_found
    assert_select "h1", text: "404"
  end
end
