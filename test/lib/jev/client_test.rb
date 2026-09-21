# frozen_string_literal: true

require "test_helper"

class Jev::ClientTest < ActiveSupport::TestCase
  # Jev::Client sleeps between retries; this subclass records the waits instead
  # of pausing the suite. Minitest 6 no longer ships Object#stub, so the seam is
  # a subclass rather than a monkeypatch.
  class PatientClient < Jev::Client
    attr_reader :waits

    private

    def sleep(seconds)
      (@waits ||= []) << seconds
    end
  end

  setup do
    @questions = [ { id: :security, type: "score", instructions: "?", criteria: [ "a", "b" ] } ]
  end

  # A real Net::HTTPResponse subclass, with the body and the read flag set so
  # `body` never tries to touch a socket.
  def response(klass, code, body)
    klass.new("1.1", code, "OK").tap do |res|
      res.instance_variable_set(:@body, body)
      res.instance_variable_set(:@read, true)
    end
  end

  def body(model: "m", answers: { "security" => { "score" => 1.0 } }, usage: { "input_tokens" => 5 })
    JSON.generate("model" => model, "answers" => answers, "usage" => usage)
  end

  test "sends the questions as a map keyed by id and parses the answers" do
    seen = nil
    transport = lambda do |payload, api_key|
      seen = [ payload, api_key ]
      body
    end

    result = Jev::Client.new(api_key: "key", transport: transport)
                       .evaluate(state: { "a" => 1 }, questions: @questions)

    assert_equal "m", result[:model]
    assert_equal({ "score" => 1.0 }, result[:answers]["security"])
    assert_equal 5, result[:usage]["input_tokens"]
    assert_equal "key", seen[1]
    assert_equal({ state: { "a" => 1 }, model: Jev::MODEL,
                   questions: { security: { type: "score", instructions: "?",
                                            criteria: [ "a", "b" ] } } },
                 seen[0])
  end

  test "retries a rate limit and then succeeds" do
    attempts = 0
    transport = lambda do |_payload, _api_key|
      attempts += 1
      raise Jev::RateLimited, "slow down" if attempts == 1

      body
    end

    client = PatientClient.new(api_key: "key", transport: transport)
    result = client.evaluate(state: "s", questions: @questions)

    assert_equal "m", result[:model]
    assert_equal 2, attempts
    assert_equal [ 1.0 ], client.waits
  end

  test "retries an overloaded service and gives up after the limit" do
    attempts = 0
    transport = lambda do |_payload, _api_key|
      attempts += 1
      raise Jev::Unavailable, "overloaded"
    end

    client = PatientClient.new(api_key: "key", transport: transport)

    assert_raises(Jev::Unavailable) { client.evaluate(state: "s", questions: @questions) }
    assert_equal Jev::Client::RETRIES + 1, attempts
    assert_equal 3, client.waits.length
  end

  test "does not retry a client error" do
    attempts = 0
    transport = lambda do |_payload, _api_key|
      attempts += 1
      raise Jev::Error, "bad request"
    end

    client = Jev::Client.new(api_key: "key", transport: transport)

    assert_raises(Jev::Error) { client.evaluate(state: "s", questions: @questions) }
    assert_equal 1, attempts
  end

  test "a 429 response raises RateLimited" do
    http = ->(_request) { response(Net::HTTPTooManyRequests, "429", "slow down") }
    client = PatientClient.new(api_key: "key", http: http)

    assert_raises(Jev::RateLimited) { client.evaluate(state: "s", questions: @questions) }
  end

  test "a server error raises Unavailable" do
    http = ->(_request) { response(Net::HTTPInternalServerError, "500", "boom") }
    client = PatientClient.new(api_key: "key", http: http)

    assert_raises(Jev::Unavailable) { client.evaluate(state: "s", questions: @questions) }
  end

  test "an unprocessable response raises Error with the status" do
    http = ->(_request) { response(Net::HTTPUnprocessableEntity, "422", "bad field") }

    error = assert_raises(Jev::Error) do
      Jev::Client.new(api_key: "key", http: http).evaluate(state: "s", questions: @questions)
    end

    assert_match "TypeSafe 422", error.message
  end

  test "a success response is parsed" do
    http = ->(_request) { response(Net::HTTPOK, "200", body) }

    result = Jev::Client.new(api_key: "key", http: http)
                        .evaluate(state: "s", questions: @questions)

    assert_equal "m", result[:model]
  end

  test "the request carries the auth header, the JSON body, and the endpoint" do
    seen = nil
    http = lambda do |request|
      seen = request
      response(Net::HTTPOK, "200", body)
    end

    Jev::Client.new(api_key: "key", http: http)
               .evaluate(state: { "a" => 1 }, questions: @questions)

    assert_equal "Bearer key", seen["Authorization"]
    assert_equal "application/json", seen["Content-Type"]
    assert_equal "POST", seen.method
    assert_equal Jev::ENDPOINT.to_s, seen.uri.to_s
    assert_equal({ "a" => 1 }, JSON.parse(seen.body)["state"])
    assert_equal Jev::MODEL, JSON.parse(seen.body)["model"]
    assert_equal [ "security" ], JSON.parse(seen.body)["questions"].keys
  end

  test "the default HTTP call goes to the endpoint over TLS" do
    original = Net::HTTP.method(:start)
    ok = response(Net::HTTPOK, "200", body)
    fake_http = Object.new
    fake_http.define_singleton_method(:request) { |_request| ok }
    seen = nil

    Net::HTTP.define_singleton_method(:start) do |host, port, use_ssl:, &block|
      seen = [ host, port, use_ssl ]
      block.call(fake_http)
    end

    result = Jev::Client.new(api_key: "key").evaluate(state: "s", questions: @questions)

    assert_equal "m", result[:model]
    assert_equal [ Jev::ENDPOINT.host, Jev::ENDPOINT.port, true ], seen
  ensure
    Net::HTTP.define_singleton_method(:start, original)
  end

  test "the api key defaults to the environment" do
    ENV["TYPESAFE_API_KEY"] = "from-env"

    assert_equal "from-env", Jev::Client.new.instance_variable_get(:@api_key)
  ensure
    ENV.delete("TYPESAFE_API_KEY")
  end
end
