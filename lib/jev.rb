# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

# TypeSafe's Jev (System One) as a project scorecard. Jev returns typed
# judgments over a piece of state; this module owns the state it is given,
# the dimensions it is asked about, and the thresholds the result is held to.
#
# Nothing here runs unless TYPESAFE_API_KEY is set (see Jev.enabled?), so a
# fork without the secret skips the check instead of failing it.
module Jev
  ENDPOINT = URI("https://api.typesafe.ai/v1/systemone")
  MODEL = "jev-latest"

  # Facts Jev needs to judge a file in context rather than in a vacuum.
  PROJECT = <<~TEXT.freeze
    Tarkov Unlockables is a Rails 8.1 / Ruby 4.0 app serving a static
    Escape-from-Tarkov dataset. It is read-mostly and data-first: importers
    write the dataset, the web app only reads it. Admin controllers
    authenticate through Admin::ApplicationController and are not public.
    CI enforces rubocop, brakeman, bundler-audit, fasterer, >=89% line and
    >=95% branch coverage, and a rubycritic score of at least 75.
  TEXT

  # A failed request. RateLimited and Unavailable are retried; the rest are not.
  class Error < StandardError; end
  class RateLimited < Error; end
  class Unavailable < Error; end

  class << self
    def api_key
      ENV["TYPESAFE_API_KEY"].to_s
    end

    def enabled?
      !api_key.empty?
    end
  end
end
