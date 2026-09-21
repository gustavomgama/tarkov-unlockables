# frozen_string_literal: true

# The Ask feature talks to Jev over the network. Tests swap in a client that
# returns canned answers, so the resolver, the controller and the view are
# exercised without a key or a request.
module AskTestHelpers
  class FakeJevClient
    def initialize(answers)
      @answers = answers
    end

    def evaluate(state:, questions:)
      { model: "fake", answers: @answers, usage: {} }
    end
  end

  # A Jev::Client stand-in that raises, for the unreachable-API path.
  class FailingJevClient
    def evaluate(state:, questions:)
      raise Jev::Unavailable, "down"
    end
  end

  def fake_jev_client(answers)
    FakeJevClient.new(answers)
  end

  def failing_jev_client
    FailingJevClient.new
  end

  def entity(token, confidence: 0.9)
    { "choice" => token, "confidence" => confidence }
  end

  def intent(choice, confidence: 0.9)
    { "choice" => choice, "confidence" => confidence }
  end
end
