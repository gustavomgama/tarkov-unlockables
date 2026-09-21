# frozen_string_literal: true

module Jev
  # Thin HTTP client for the System One endpoint. The transport and the HTTP
  # call are injectable so the suite never touches the network: tests pass a
  # fake transport to exercise retries and a fake HTTP call to exercise status
  # handling.
  class Client
    RETRIES = 3

    def initialize(api_key: Jev.api_key, transport: nil, http: nil)
      @api_key = api_key
      @transport = transport || method(:post)
      @http = http || method(:perform)
    end

    # Returns { model:, answers:, usage: } for the questions, retrying only the
    # failures that a retry can fix (rate limit, overload).
    def evaluate(state:, questions:)
      payload = {
        state: state,
        model: MODEL,
        questions: questions.to_h { |question| [ question[:id], question.except(:id) ] }
      }

      attempt = 0
      begin
        parse(@transport.call(payload, @api_key))
      rescue RateLimited, Unavailable => error
        attempt += 1
        raise error if attempt > RETRIES

        sleep(0.5 * (2**attempt))
        retry
      end
    end

    private

    def post(payload, api_key)
      request = Net::HTTP::Post.new(ENDPOINT)
      request["Authorization"] = "Bearer #{api_key}"
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(payload)
      classify(@http.call(request))
    end

    def perform(request)
      Net::HTTP.start(ENDPOINT.host, ENDPOINT.port, use_ssl: true) do |http|
        http.request(request)
      end
    end

    def classify(response)
      status = response.code.to_i
      raise RateLimited, response.body if status == 429
      raise Unavailable, response.body if status >= 500
      raise Error, "TypeSafe #{status}: #{response.body}" unless response.is_a?(Net::HTTPSuccess)

      response.body
    end

    def parse(body)
      data = JSON.parse(body)
      { model: data["model"], answers: data["answers"], usage: data["usage"] }
    end
  end
end
