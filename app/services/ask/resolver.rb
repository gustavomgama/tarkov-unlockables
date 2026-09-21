# frozen_string_literal: true

module Ask
  # Routes a free-text question to one of the candidates and to an intent.
  #
  # Code retrieves the candidates and composes the answer; Jev only picks, and
  # its confidence decides whether the pick is used at all. Everything below the
  # confidence floor falls back to the candidate list, so a wrong or unsure
  # judgment costs a worse answer, never a wrong one.
  class Resolver
    MIN_CONFIDENCE = 0.5

    INTENTS = {
      "obtain" => "How to get or unlock it: trader, barter, craft, quest reward or hideout",
      "cost" => "What it needs or what it costs: build requirements, ingredients, price",
      "reward" => "Which quest or activity hands it out",
      "location" => "Where to find it: which map, trader or station",
      "other" => "Anything the other options do not cover"
    }.freeze

    def self.call(question, client: nil, candidates: nil)
      new(question, client: client, candidates: candidates).call
    end

    def initialize(question, client: nil, candidates: nil)
      @question = question.to_s.strip
      @client = client
      @candidates = candidates
    end

    def call
      entries = candidates
      return Answer.unresolved(@question) if entries.empty?

      answers = evaluate(entries)
      entry = pick(entries, answers)
      return Answer.unresolved(@question, entries: entries) if entry.nil?

      Answer.new(question: @question, entry: entry, intent: intent(answers),
                 confidence: answers.dig("entity", "confidence").to_f)
    rescue Jev::Error
      # The API is unreachable or the key is wrong. Answer with the candidates
      # instead of failing the request.
      Answer.unresolved(@question, entries: entries)
    end

    private

    def candidates
      @candidates ||= Candidates.call(@question)
    end

    # Built from the environment only when a question is actually asked, so the
    # app boots and serves every other page without a key.
    def client
      return @client if @client
      return nil unless Jev.enabled?

      @client = Jev::Client.new
    end

    def evaluate(entries)
      return {} if client.nil?

      client.evaluate(state: state(entries), questions: questions(entries))[:answers].to_h
    end

    def state(entries)
      {
        question: @question,
        candidates: entries.map { |entry| { token: entry.token, label: entry.label } }
      }
    end

    def questions(entries)
      [
        { id: :entity, type: "choice",
          instructions: "Which entry in `candidates` is the question about?",
          criteria: entity_criteria(entries) },
        { id: :intent, type: "choice",
          instructions: "What does the question ask about the thing it names?",
          criteria: INTENTS }
      ]
    end

    def entity_criteria(entries)
      criteria = entries.to_h { |entry| [ entry.token, entry.label ] }
      criteria["none"] = "None of these is what the question is about"
      criteria
    end

    def pick(entries, answers)
      answer = answers["entity"]
      return nil if answer.nil?
      return nil if answer["confidence"].to_f < MIN_CONFIDENCE

      entries.detect { |entry| entry.token == answer["choice"] }
    end

    def intent(answers)
      answer = answers["intent"]
      return "obtain" if answer.nil? || answer["confidence"].to_f < MIN_CONFIDENCE

      answer["choice"]
    end
  end
end
