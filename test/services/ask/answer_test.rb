# frozen_string_literal: true

require "test_helper"

module Ask
  class AnswerTest < ActiveSupport::TestCase
    def entry(token, record)
      Candidates::Entry.new(token: token, label: "Label", record: record)
    end

    test "unresolved carries the question and the candidate list" do
      answer = Answer.unresolved("what?", entries: [ :a ])

      refute answer.resolved?
      assert_equal "what?", answer.question
      assert_equal [ :a ], answer.entries
      assert_nil answer.record
      assert_nil answer.kind
      assert_nil answer.title
      assert_empty answer.routes
    end

    test "an item exposes every acquisition route" do
      item = create_item("Routed Item", short_name: "RI")
      task = create_task("Routed Task", "routed-task", given_by: "Prapor")
      item.item_currencies.create!(trader: "Prapor", currency: "RUB", min_trader_level: 2,
                                   price: 12_345, buy_limit: 3)
      item.item_currencies.create!(trader: "Peacekeeper", currency: "USD", min_trader_level: 3,
                                   task_unlock: true)
      barter = item.item_barters.create!(trader: "Therapist", trader_level: "2")
      barter.item_barter_requirements.create!(item_name: "Bandage", count: 2)
      item.item_hideouts.create!(station: "Medstation", level: 1, count: 3)
      item.item_task_rewards.create!(task: task)

      answer = Answer.new(question: "how", entry: entry("item:#{item.slug}", item), intent: "obtain")

      assert answer.resolved?
      assert_equal "Label", answer.title
      assert_equal "item", answer.kind
      assert_equal item, answer.record

      kinds = answer.routes.map(&:kind)
      assert_includes kinds, "Trader"
      assert_includes kinds, "Barter"
      assert_includes kinds, "Hideout"
      assert_includes kinds, "Quest"

      trader = answer.routes.find { |r| r.kind == "Trader" }
      assert_equal "Prapor LL2", trader.label
      assert_equal "12,345 RUB · buy limit 3", trader.detail

      gated = answer.routes.reverse.detect { |r| r.kind == "Trader" }
      assert_equal "task-gated", gated.detail

      hideout = answer.routes.find { |r| r.kind == "Hideout" }
      assert_equal "Medstation level 1", hideout.label
      assert_equal "×3 per craft", hideout.detail
    ensure
      item&.destroy
      task&.destroy
    end

    test "a hideout route says crafted here when the craft makes one" do
      item = create_item("Single Craft", short_name: "SC")
      item.item_hideouts.create!(station: "Workbench", level: 2, count: 1)

      answer = Answer.new(question: "how", entry: entry("item:#{item.slug}", item))

      route = answer.routes.find { |r| r.kind == "Hideout" }
      assert_equal "crafted here", route.detail
    ensure
      item&.destroy
    end

    test "a quest reward falls back to the stored name when no task is linked" do
      item = create_item("Orphan Reward", short_name: "OR")
      item.item_task_rewards.create!(task_name: "Missing Quest")

      answer = Answer.new(question: "how", entry: entry("item:#{item.slug}", item))

      route = answer.routes.find { |r| r.kind == "Quest" }
      assert_equal "Missing Quest", route.label
    ensure
      item&.destroy
    end

    test "a station exposes its build levels" do
      station = HideoutStation.create!(bsg_id: "a-#{SecureRandom.hex(4)}", slug: "ans-lav-#{SecureRandom.hex(3)}",
                                       name: "Lavatory")
      level = station.hideout_levels.create!(level: 2)
      level.hideout_item_requirements.create!(item_name: "Wires", count: 3)

      answer = Answer.new(question: "what", entry: entry("station:#{station.slug}", station),
                          intent: "cost")

      assert_equal "station", answer.kind
      assert_equal 1, answer.routes.length
      assert_equal "Level 2", answer.routes.first.kind
      assert_equal "Wires ×3", answer.routes.first.detail
    ensure
      station&.destroy
    end

    test "a trader is answered by its own page, with no rows" do
      trader = Trader.create!(bsg_id: "a-#{SecureRandom.hex(4)}", slug: "ans-prap-#{SecureRandom.hex(3)}",
                              name: "Prapor", currency: "RUB")

      answer = Answer.new(question: "who", entry: entry("trader:#{trader.slug}", trader))

      assert_equal "trader", answer.kind
      assert_empty answer.routes
    ensure
      trader&.destroy
    end
  end
end
