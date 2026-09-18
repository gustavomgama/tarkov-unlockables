# frozen_string_literal: true

require "test_helper"

# Two sweeps that assert a shape of behaviour rather than a single page:
# no reachable URL may answer 5xx for hostile input, and the app answers 406
# (not a MissingTemplate 500) when asked for a format it does not render.
class HostileSweepTest < ActionDispatch::IntegrationTest
  include AdminRequestAuth

  fixtures :all

  HOSTILE_PARAMS = [
    { q: "x" }, { q: [ "x" ] }, { q: "%%%" }, { q: "a" * 3000 }, { q: "" },
    { page: "-1" }, { page: "abc" }, { page: "99999999" }, { page: [ "1" ] },
    { per_page: "0" }, { per_page: "-5" }, { per_page: "abc" }, { per_page: "99999" },
    { trader: [ "x" ] }, { kappa: "1" }, { format: "json" }, { format: "xml" },
    { filters: "x" }, { filters: [ "x" ] }, { filters: { category: [ 'x"y' ] } },
    { filters: { caliber: [ "" ] } }, { filters: { source: [ "nope" ] } },
    { filters: { currency: [ "RUB" ] }, q: "a" },
    { item_id: "abc" }, { id: "abc" }, { sort: "weight" }, { order: "desc" }
  ].freeze

  PUBLIC_PATHS = %w[
    / /items /items/search /tasks /tasks/search /tasks/chains /favorites /manifest /service-worker
  ].freeze

  ADMIN_PATHS = %w[
    /admin/items /admin/items/new /admin/tasks /admin/requirements /admin/rewards
    /admin/leads_tos /admin/previous_tasks /admin/barter_unlocks /admin/craft_unlocks
    /admin/offer_unlocks /admin/dashboard
  ].freeze

  # Every one of these was a 500 before the format guard: `.json`/`?format=xml`
  # reached the view layer and raised ActionView::MissingTemplate.
  test "no page answers 5xx for hostile params, on any route" do
    offenders = []

    (PUBLIC_PATHS + ADMIN_PATHS).each do |path|
      admin = ADMIN_PATHS.include?(path)

      HOSTILE_PARAMS.each do |params|
        admin ? get_auth(path, params: params) : get(path, params: params)
        offenders << "#{path} #{params.inspect} -> #{response.status}" if response.status >= 500
      end
    end

    assert_empty offenders, "5xx responses: #{offenders.join(', ')}"
  end

  test "a non-HTML format is refused instead of raising a missing template" do
    [ "/items.json", "/items?format=json", "/items?format=xml", "/tasks.json",
      "/tasks/chains.json", "/favorites.json" ].each do |path|
      get path
      assert_response :not_acceptable, "#{path} should be 406"
    end
  end

  test "an API-style Accept header is refused too" do
    get items_url, headers: { "Accept" => "application/json" }

    assert_response :not_acceptable
  end

  # Turbo carries turbo-stream in its Accept header on every navigation; a 406
  # here would break every link and form on the site.
  test "Turbo requests still render" do
    get items_url, headers: { "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml" }

    assert_response :success
  end

  # `*/*` is the default Accept of curl, health checkers and many HTTP clients.
  # It is a wildcard, not a request for a non-HTML format — treating it as one
  # made every page 406 for those clients (caught in the production-image
  # rehearsal, where curl could not load a single page).
  test "a wildcard Accept header renders HTML" do
    get items_url, headers: { "Accept" => "*/*" }

    assert_response :success
  end

  test "the PWA endpoints keep their own formats" do
    get "/manifest"
    assert_response :success

    get "/service-worker"
    assert_response :success
  end
end
