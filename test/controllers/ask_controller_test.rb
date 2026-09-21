# frozen_string_literal: true

require "test_helper"

class AskControllerTest < ActionDispatch::IntegrationTest
  include AskTestHelpers

  teardown { AskController.jev_client = nil }

  test "get without a question renders the form only" do
    get ask_url

    assert_response :success
    assert_select "form[action=?]", ask_path
    assert_select "p", text: /I could not tell/, count: 0
  end

  test "a resolved item question links to the item page and its routes" do
    item = create_item("Asked Item", short_name: "AI")
    item.item_currencies.create!(trader: "Prapor", currency: "RUB", min_trader_level: 1, price: 900)
    AskController.jev_client = fake_jev_client(
      "entity" => entity("item:#{item.slug}"), "intent" => intent("obtain")
    )

    get ask_url(q: "how do I unlock Asked Item?")

    assert_response :success
    assert_select "strong", text: "Asked Item (AI)"
    assert_select ".srcrow", text: /Prapor LL1/
    assert_select "a[href=?]", item_path(item)
  ensure
    item&.destroy
  end

  test "a resolved station question links to the station page" do
    station = HideoutStation.create!(bsg_id: "ak-#{SecureRandom.hex(4)}", slug: "asked-station",
                                     name: "Asked Station")
    station.hideout_levels.create!(level: 1)
    AskController.jev_client = fake_jev_client(
      "entity" => entity("station:#{station.slug}"), "intent" => intent("cost")
    )

    get ask_url(q: "what does Asked Station need?")

    assert_response :success
    assert_select "a[href=?]", station_path(station.slug)
    assert_select ".srcrow", text: /build requirements/
  ensure
    station&.destroy
  end

  test "a resolved trader question links to the trader page with no rows" do
    trader = Trader.create!(bsg_id: "ak-#{SecureRandom.hex(4)}", slug: "asked-trader",
                            name: "Asked Trader", currency: "RUB")
    AskController.jev_client = fake_jev_client(
      "entity" => entity("trader:#{trader.slug}"), "intent" => intent("other")
    )

    get ask_url(q: "who is Asked Trader?")

    assert_response :success
    assert_select "a[href=?]", trader_path(trader.slug)
    assert_select "p", text: /has the full answer/
  ensure
    trader&.destroy
  end

  test "a resolved task question links to the task page" do
    task = create_task("Asked Task", "asked-task", given_by: "Prapor")
    AskController.jev_client = fake_jev_client(
      "entity" => entity("task:#{task.id}"), "intent" => intent("reward")
    )

    get ask_url(q: "who gives Asked Task?")

    assert_response :success
    assert_select "a[href=?]", task_path(task)
  ensure
    task&.destroy
  end

  test "an unresolved question lists the candidates it found" do
    item = create_item("Unresolved Item", short_name: "UI")
    AskController.jev_client = fake_jev_client("entity" => entity("none"), "intent" => intent("other"))

    get ask_url(q: "Unresolved Item")

    assert_response :success
    assert_select "p", text: /could not tell/
    assert_select "li", text: "Unresolved Item (UI)"
    assert_select "a[href=?]", items_path(q: "Unresolved Item")
  ensure
    item&.destroy
  end

  test "a question with no candidates falls back to the items search" do
    AskController.jev_client = fake_jev_client({})

    get ask_url(q: "zzzznotathing")

    assert_response :success
    assert_select "p", text: /Try naming an item/
    assert_select "a[href=?]", items_path(q: "zzzznotathing")
  end

  test "an unreachable API still renders the page" do
    item = create_item("Network Item", short_name: "NI")
    AskController.jev_client = failing_jev_client

    get ask_url(q: "Network Item")

    assert_response :success
    assert_select "p", text: /could not tell/
  ensure
    item&.destroy
  end
end
