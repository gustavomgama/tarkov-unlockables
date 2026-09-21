# frozen_string_literal: true

module Ask
  # The records a question could be about, retrieved in code. Jev only ever
  # picks from this list, so a resolved answer can never name a record that does
  # not exist. This is the candidate-generation half of the extraction pattern:
  # code finds the candidates, the model selects the intended one.
  class Candidates
    LIMIT = 10

    # Words that carry the question rather than name its subject.
    STOPWORDS = %w[
      a about an and are at be build buy can cost do does for from get how i
      in is it level ll me much need of on or the to unlock want what where
      which who with you
    ].freeze

    Entry = Struct.new(:token, :label, :record, keyword_init: true)

    def self.call(question)
      new(question).call
    end

    def initialize(question)
      @question = question.to_s
    end

    def call
      (items + stations + traders + tasks).uniq(&:token)
    end

    private

    # Single words plus adjacent pairs, so "magazine case" survives as one term
    # while "CBJs" and "Lavatory" survive as themselves.
    def terms
      words = @question.downcase.scan(/[a-z0-9]+/).reject do |word|
        word.length < 2 || STOPWORDS.include?(word)
      end
      (words + words.each_cons(2).map { |pair| pair.join(" ") }).uniq
    end

    # Loose search strips punctuation, and players name items in the plural
    # ("CBJs", "salewas"). The singular is what the stored search text holds.
    def variants(term)
      [ term, term.sub(/s\z/, "") ].uniq
    end

    def matching(scope, columns)
      terms.flat_map do |term|
        variants(term).flat_map do |variant|
          scope.loose_search(variant, columns: columns).limit(LIMIT).to_a
        end
      end.uniq(&:id).first(LIMIT)
    end

    def items
      matching(Item, %w[full_name short_name]).map do |item|
        Entry.new(token: "item:#{item.slug}",
                  label: "#{item.full_name} (#{item.short_name})",
                  record: item)
      end
    end

    def stations
      matching(HideoutStation, %w[name]).map do |station|
        Entry.new(token: "station:#{station.slug}",
                  label: "#{station.name} (hideout station)",
                  record: station)
      end
    end

    def traders
      matching(Trader, %w[name]).map do |trader|
        Entry.new(token: "trader:#{trader.slug}",
                  label: "#{trader.name} (trader)",
                  record: trader)
      end
    end

    def tasks
      matching(Task, %w[full_name name]).map do |task|
        Entry.new(token: "task:#{task.id}",
                  label: "#{task.full_name} (task)",
                  record: task)
      end
    end
  end
end
