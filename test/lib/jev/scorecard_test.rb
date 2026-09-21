# frozen_string_literal: true

require "test_helper"

class Jev::ScorecardTest < ActiveSupport::TestCase
  RESPONSE = { model: "m", answers: { "security" => { "score" => 1.0 } }, usage: { "input_tokens" => 1 } }.freeze

  def fake_builder
    Object.new.tap do |builder|
      builder.define_singleton_method(:call) { |path| { path: path } }
    end
  end

  def scorecard(client)
    Jev::Scorecard.new(client: client, builder: fake_builder, rubrics: Jev::Rubrics)
  end

  def responding_client
    Object.new.tap do |client|
      client.define_singleton_method(:evaluate) { |state:, questions:| RESPONSE }
    end
  end

  test "judges every path and carries the answers" do
    results = scorecard(responding_client).judge([ "a.rb", "b.rb" ])

    assert_equal [ "a.rb", "b.rb" ], results.map(&:path)
    assert results.all?(&:ok?)
    assert_equal "m", results.first.model
    assert_equal({ "score" => 1.0 }, results.first.answers["security"])
  end

  test "passes the built state and the questions to the client" do
    seen = []
    client = Object.new
    client.define_singleton_method(:evaluate) do |state:, questions:|
      seen << [ state, questions ]
      RESPONSE
    end

    scorecard(client).judge([ "a.rb" ])

    assert_equal({ path: "a.rb" }, seen.first.first)
    assert_equal Jev::Rubrics.questions_for("a.rb"), seen.first.last
    assert_equal Jev::Rubrics.keys.length, seen.first.last.length
  end

  test "records a failed judgment instead of raising" do
    client = Object.new
    client.define_singleton_method(:evaluate) { |state:, questions:| raise Jev::Error, "nope" }

    result = scorecard(client).judge([ "a.rb" ]).first

    refute result.ok?
    assert_equal "nope", result.error
    assert_nil result.answers
  end
end
