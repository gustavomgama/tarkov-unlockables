require "test_helper"

# Query strings arrive from anywhere: a hand-typed URL, a chat client cutting
# one in half, a crawler. Every one of these either 500'd at some point or was
# one type check away from it.
class HostileParamsTest < ActionDispatch::IntegrationTest
  SCALAR = "string".freeze
  ARRAY = [ "x" ].freeze

  def assert_no_server_error(url, params)
    get url, params: params
    assert_response :success, "expected 200 for #{params.inspect}"
  end

  test "items index tolerates scalar and array filter params" do
    [ { filters: SCALAR }, { filters: ARRAY }, { filters: { currency: SCALAR } },
      { filters: { armor_class: ARRAY } }, { filters: { caliber: [ "" ] } },
      { filters: { exclude_ref: SCALAR } }, { q: ARRAY }, { q: SCALAR },
      { per_page: SCALAR }, { per_page: ARRAY }, { page: ARRAY } ].each do |params|
      assert_no_server_error(items_url, params)
    end
  end

  test "tasks index tolerates scalar and array params" do
    [ { trader: ARRAY }, { trader: SCALAR }, { kappa: SCALAR }, { q: ARRAY } ].each do |params|
      assert_no_server_error(tasks_url, params)
    end
  end

  test "search endpoints ignore anything that is not a short string" do
    [ search_items_url, search_tasks_url ].each do |url|
      [ { q: ARRAY }, { q: SCALAR }, {} ].each { |params| assert_no_server_error(url, params) }
    end
  end

  test "show routes 404 rather than 500 on a junk id" do
    get item_url(id: "not-an-id")
    assert_response :not_found

    get task_url(id: "not-an-id")
    assert_response :not_found
  end
end
