# frozen_string_literal: true

require "test_helper"

class AskHelperTest < ActionView::TestCase
  include AskHelper

  def entry(token)
    Ask::Candidates::Entry.new(token: token, label: "Label", record: nil)
  end

  test "ask_target_path maps each kind to its page" do
    item = create_item("Helper Item", short_name: "HI")
    station = HideoutStation.create!(bsg_id: "h-#{SecureRandom.hex(4)}", slug: "helper-station-#{SecureRandom.hex(3)}",
                                     name: "Helper Station")
    trader = Trader.create!(bsg_id: "h-#{SecureRandom.hex(4)}", slug: "helper-trader-#{SecureRandom.hex(3)}",
                            name: "Helper Trader", currency: "RUB")
    task = create_task("Helper Task", "helper-task-#{SecureRandom.hex(3)}", given_by: "Prapor")

    assert_equal item_path(item), ask_target_path(answer_for("item:#{item.slug}", item))
    assert_equal station_path(station.slug), ask_target_path(answer_for("station:#{station.slug}", station))
    assert_equal trader_path(trader.slug), ask_target_path(answer_for("trader:#{trader.slug}", trader))
    assert_equal task_path(task), ask_target_path(answer_for("task:#{task.id}", task))
  ensure
    item&.destroy
    station&.destroy
    trader&.destroy
    task&.destroy
  end

  test "an unknown kind has no page and a generic name" do
    answer = Ask::Answer.new(question: "q", entry: entry("widget:1"))

    assert_nil ask_target_path(answer)
    assert_equal "page", ask_target_name(answer)
  end

  test "a known kind gets its readable name" do
    answer = Ask::Answer.new(question: "q", entry: entry("station:1"))

    assert_equal "hideout page", ask_target_name(answer)
  end

  private

  def answer_for(token, record)
    Ask::Answer.new(question: "q", entry: Ask::Candidates::Entry.new(token: token, label: "L", record: record))
  end
end
