# frozen_string_literal: true

module Jev
  # Judges a list of files, one result per file. A failed judgment is recorded
  # as a result carrying its error rather than raised, so one unreachable file
  # cannot hide the rest of the scorecard.
  class Scorecard
    Result = Struct.new(:path, :answers, :model, :usage, :error, keyword_init: true) do
      def ok?
        error.nil?
      end
    end

    def initialize(client: Client.new, builder: StateBuilder.new, rubrics: Rubrics)
      @client = client
      @builder = builder
      @rubrics = rubrics
    end

    def judge(paths)
      paths.map { |path| judge_one(path) }
    end

    private

    def judge_one(path)
      questions = @rubrics.questions_for(path)
      response = @client.evaluate(state: @builder.call(path), questions: questions)
      Result.new(path: path, answers: response[:answers], model: response[:model],
                 usage: response[:usage])
    rescue Jev::Error => error
      Result.new(path: path, error: error.message)
    end
  end
end
