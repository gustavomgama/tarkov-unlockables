# frozen_string_literal: true

module Ask
  # What a question resolved to, plus the answer composed in code from the
  # record. Nothing here is model output: Jev chose the record and the intent,
  # and every fact below comes from the database.
  class Answer
    Route = Struct.new(:kind, :label, :detail, keyword_init: true)

    attr_reader :question, :entry, :intent, :confidence, :entries

    def self.unresolved(question, entries: [])
      new(question: question, entries: entries)
    end

    def initialize(question:, entry: nil, intent: nil, confidence: 0.0, entries: [])
      @question = question
      @entry = entry
      @intent = intent
      @confidence = confidence
      @entries = entries
    end

    def resolved?
      !entry.nil?
    end

    def record
      entry&.record
    end

    def kind
      entry&.token&.split(":")&.first
    end

    def title
      entry&.label
    end

    # The rows that answer the question. Items get every acquisition route,
    # stations get their build levels; anything else is answered by its own
    # page, which the view links to.
    def routes
      case kind
      when "item" then item_routes
      when "station" then station_routes
      else []
      end
    end

    private

    def item_routes
      trader_routes + barter_routes + hideout_routes + quest_routes
    end

    def trader_routes
      offers = record.item_currencies.uniq do |offer|
        [ offer.trader, offer.currency, offer.min_trader_level ]
      end

      offers.map do |offer|
        Route.new(kind: "Trader",
                  label: "#{offer.trader.to_s.titleize} LL#{offer.min_trader_level}",
                  detail: offer_detail(offer))
      end
    end

    def offer_detail(offer)
      parts = []
      parts << "#{number(offer.price)} #{offer.currency}" if offer.price.present?
      parts << "buy limit #{offer.buy_limit}" if offer.buy_limit.present?
      parts << "task-gated" if offer.task_unlock?
      parts.join(" · ")
    end

    def barter_routes
      record.item_barters.map do |barter|
        needs = barter.item_barter_requirements.map { |req| "#{req.item_name} ×#{req.count}" }
        Route.new(kind: "Barter",
                  label: "#{barter.trader.to_s.titleize} LL#{barter.trader_level}",
                  detail: needs.to_sentence)
      end
    end

    def hideout_routes
      record.item_hideouts.map do |hideout|
        detail = hideout.count.to_i > 1 ? "×#{hideout.count} per craft" : "crafted here"
        Route.new(kind: "Hideout",
                  label: "#{hideout.station} level #{hideout.level}",
                  detail: detail)
      end
    end

    def quest_routes
      record.item_task_rewards.map do |reward|
        Route.new(kind: "Quest",
                  label: reward.task&.full_name || reward.task_name,
                  detail: "quest reward")
      end
    end

    def station_routes
      record.hideout_levels.includes(:hideout_item_requirements).map do |level|
        needs = level.hideout_item_requirements.map { |req| "#{req.item_name} ×#{req.count}" }
        Route.new(kind: "Level #{level.level}", label: "build requirements",
                  detail: needs.to_sentence)
      end
    end

    def number(value)
      ActiveSupport::NumberHelper.number_to_delimited(value)
    end
  end
end
