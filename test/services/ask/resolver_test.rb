# frozen_string_literal: true

require "test_helper"

module Ask
  class ResolverTest < ActiveSupport::TestCase
    include AskTestHelpers

    setup do
      @item = create_item("Resolver Item", short_name: "RI")
      @entries = [ Candidates::Entry.new(token: "item:#{@item.slug}", label: "Resolver Item (RI)",
                                         record: @item) ]
    end

    teardown { @item&.destroy }

    test "resolves the picked candidate and the intent" do
      client = fake_jev_client("entity" => entity("item:#{@item.slug}"),
                               "intent" => intent("obtain"))

      answer = Resolver.call("how do I get Resolver Item?", client: client, candidates: @entries)

      assert answer.resolved?
      assert_equal @item, answer.record
      assert_equal "obtain", answer.intent
      assert_in_delta 0.9, answer.confidence
    end

    test "an empty candidate list is unresolved and never calls the API" do
      answer = Resolver.call("nothing here", client: fake_jev_client({}), candidates: [])

      refute answer.resolved?
      assert_equal "nothing here", answer.question
      assert_empty answer.entries
    end

    test "a pick below the confidence floor keeps the candidate list and no answer" do
      client = fake_jev_client("entity" => entity("item:#{@item.slug}", confidence: 0.4),
                               "intent" => intent("obtain"))

      answer = Resolver.call("maybe?", client: client, candidates: @entries)

      refute answer.resolved?
      assert_equal @entries, answer.entries
    end

    test "the none option is unresolved" do
      client = fake_jev_client("entity" => entity("none"), "intent" => intent("other"))

      answer = Resolver.call("none of these", client: client, candidates: @entries)

      refute answer.resolved?
      assert_equal @entries, answer.entries
    end

    test "a missing entity answer is unresolved" do
      client = fake_jev_client("intent" => intent("other"))

      answer = Resolver.call("no entity", client: client, candidates: @entries)

      refute answer.resolved?
    end

    test "an unsure or missing intent falls back to obtain" do
      [
        fake_jev_client("entity" => entity("item:#{@item.slug}")),
        fake_jev_client("entity" => entity("item:#{@item.slug}"), "intent" => intent("cost", confidence: 0.2))
      ].each do |client|
        answer = Resolver.call("what is it?", client: client, candidates: @entries)

        assert_equal "obtain", answer.intent
      end
    end

    test "an unreachable API answers with the candidate list" do
      answer = Resolver.call("anything", client: failing_jev_client, candidates: @entries)

      refute answer.resolved?
      assert_equal @entries, answer.entries
    end

    test "without a client or a key, the question is answered from the candidates" do
      key = ENV.delete("TYPESAFE_API_KEY")

      answer = Resolver.call("anything", candidates: @entries)

      refute answer.resolved?
      assert_equal @entries, answer.entries
    ensure
      ENV["TYPESAFE_API_KEY"] = key if key
    end

    test "builds the client from the key when none is injected" do
      key = ENV["TYPESAFE_API_KEY"]
      ENV["TYPESAFE_API_KEY"] = "key"

      resolver = Resolver.new("how do I get Resolver Item?", candidates: @entries)

      assert_instance_of Jev::Client, resolver.send(:client)
    ensure
      key ? ENV["TYPESAFE_API_KEY"] = key : ENV.delete("TYPESAFE_API_KEY")
    end
  end
end
