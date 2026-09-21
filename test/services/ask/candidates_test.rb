# frozen_string_literal: true

require "test_helper"

module Ask
  class CandidatesTest < ActiveSupport::TestCase
    test "finds an item whose name the question names, however it is pluralised" do
      item = create_item("CBJ", short_name: "CBJ")
      create_item("Salewa First Aid Kit", short_name: "Salewa")

      entry = Candidates.call("how do I unlock CBJs?").find { |e| e.record == item }

      assert_not_nil entry
      assert_equal "item:#{item.slug}", entry.token
      assert_equal "CBJ (CBJ)", entry.label
    ensure
      Item.where(full_name: [ "CBJ", "Salewa First Aid Kit" ]).delete_all
    end

    test "finds a station, a trader and a task by name" do
      station = HideoutStation.create!(bsg_id: "c-#{SecureRandom.hex(4)}", slug: "cand-lav-#{SecureRandom.hex(3)}",
                                       name: "Lavatory")
      trader = Trader.create!(bsg_id: "c-#{SecureRandom.hex(4)}", slug: "cand-prapor-#{SecureRandom.hex(3)}",
                              name: "Prapor", currency: "RUB")
      task = create_task("The Guide", "the-guide", given_by: "Prapor")

      entries = Candidates.call("what does Prapor want for The Guide at the Lavatory?")

      assert_includes entries.map(&:token), "station:#{station.slug}"
      assert_includes entries.map(&:token), "trader:#{trader.slug}"
      assert_includes entries.map(&:token), "task:#{task.id}"
    ensure
      station&.destroy
      trader&.destroy
      task&.destroy
    end

    test "a question of only stopwords finds nothing" do
      assert_empty Candidates.call("how do I get it?")
    end

    test "a blank question finds nothing" do
      assert_empty Candidates.call("   ")
    end

    test "tokens are unique across record kinds" do
      create_item("Unique Thing", short_name: "UT")
      task = create_task("Unique Thing", "unique-thing", given_by: "Prapor")

      tokens = Candidates.call("Unique Thing").map(&:token)

      assert_equal tokens.uniq, tokens
      assert_includes tokens, "task:#{task.id}"
    ensure
      Item.where(full_name: "Unique Thing").delete_all
      task&.destroy
    end

    test "caps the candidate list" do
      12.times { |i| create_item("Cap Item #{i}", short_name: "CI#{i}") }

      assert_operator Candidates.call("cap item").length, :<=, Candidates::LIMIT
    ensure
      Item.where("full_name LIKE 'Cap Item %'").delete_all
    end
  end
end
