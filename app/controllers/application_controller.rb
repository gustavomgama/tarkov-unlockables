class ApplicationController < ActionController::Base
  include LooseSearchable
  include HtmlOnly

  # Shared typeahead tuning, used by both the item and task search fields.
  AUTOCOMPLETE_LIMIT = 8
  AUTOCOMPLETE_MIN_QUERY = 2

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, CSS :has.
  allow_browser versions: :modern

  # Most recently declared handler wins, so every specific handler must come
  # after the catch-all or it is shadowed (RecordNotFound would render as 500).
  #
  # The client-error classes are handled explicitly because the catch-all would
  # otherwise report them as server errors: Rails maps a missing required param
  # and a malformed JSON body to 400 and an expired/forged CSRF token to 422, but
  # a StandardError handler intercepts them first and they surface as 500s —
  # misleading for users and noise in error tracking.
  rescue_from StandardError, with: :internal_server_error unless Rails.env.development?
  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActionController::RoutingError, with: :not_found
  rescue_from ActionController::ParameterMissing, with: :bad_request
  rescue_from ActionDispatch::Http::Parameters::ParseError, with: :bad_request
  rescue_from ActionController::InvalidAuthenticityToken, with: :unprocessable_content

  # Preloaded name → task map shared by every Task#prerequisite_chain call
  # in views. Lazy per request: pages that render no raid timeline issue
  # zero queries for it (and never trip Bullet's unused-preload check).
  def task_map
    @task_map ||= Task.includes(requirements: :previous_tasks).index_by(&:name)
  end
  helper_method :task_map

  private

  # A query-string value can arrive as an array ("?per_page[]=x"), and an array
  # has no #to_i: read the first entry, or none. Shared by the items listing and
  # the admin Paginatable concern.
  def int_param(name)
    value = params[name]
    value = value.first if value.is_a?(Array)
    value.to_i
  end

  # Applies a loose search only when ?q= is present, otherwise returns the
  # scope untouched (blank/absent query must not narrow the listing).
  def loose_search_param(scope, columns)
    query = params[:q]
    return scope if query.blank?

    scope.loose_search(query, columns: columns)
  end

  # Shared typeahead: a too-short or empty result set is a 204, otherwise the
  # model's autocomplete partial renders the capped row list. The row markup
  # lives in the partial so nothing is rebuilt in JavaScript.
  def autocomplete(scope, columns:, partial:, local:)
    query = params[:q].to_s.strip
    return head :no_content if query.length < AUTOCOMPLETE_MIN_QUERY

    records = scope.loose_search(query, columns: columns)
                   .order(full_name: :asc)
                   .limit(AUTOCOMPLETE_LIMIT)
    return head :no_content if records.empty?

    expires_in 10.minutes, public: true
    render partial: partial, locals: { local => records }, layout: false
  end

  def not_found
    render "errors/not_found", status: :not_found
  end

  # The request was malformed (a required param missing, an unparsable body):
  # nothing to render beyond the status.
  def bad_request
    head :bad_request
  end

  # The CSRF token is missing, stale or forged — the form must be reloaded.
  def unprocessable_content
    head :unprocessable_content
  end

  def internal_server_error
    render "errors/internal_server_error", status: :internal_server_error
  end
end
