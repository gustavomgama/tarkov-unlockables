# frozen_string_literal: true

require "test_helper"

# The read sweep (hostile_sweep_test.rb) covers GET; this one drives the write
# routes with malformed payloads. It found the admin create/update 500 on an
# unknown STI `type`, which no page test reached because the form only ever
# offers Item.descendants.
class HostileWriteSweepTest < ActionDispatch::IntegrationTest
  include AdminRequestAuth

  fixtures :all

  PAYLOADS = {
    "item" => [
      { type: "Bogus" }, { type: "" }, { type: "User" }, { data: "not json" },
      { data: { "a" => 1 } }, { categories: "a,b" }, { categories: { "0" => "x" } },
      { categories: [ "a", [ "b" ] ] }, { links: [ "javascript:alert(1)" ] },
      { full_name: "" }, { bsg_id: "x" * 5000 },
      { item_currencies_attributes: { "0" => { id: "999999999", _destroy: "1" } } },
      { item_hideouts_attributes: { "0" => { id: "abc" } } }
    ],
    "task" => [ { bsg_id: "" }, { name: "" }, { full_name: "" }, { given_by: [ "x" ] } ],
    "requirement" => [ { task_id: "abc" }, { player_level: "abc" }, { player_level: [ "1" ] },
                       { previous_tasks_count: "abc" }, { trader_level: { "a" => 1 } } ],
    "reward" => [ { task_id: "abc" }, { reward_type: "" } ],
    "leads_to" => [ { task_id: "abc" }, { follow_up_task_id: "abc" } ],
    "previous_task" => [ { requirement_id: "abc" }, { task_id: "abc" } ],
    "barter_unlock" => [ { reward_id: "abc" }, { item_id: "abc" }, { item_name: "" } ],
    "craft_unlock" => [ { reward_id: "abc" }, { station_level: "abc" } ],
    "offer_unlock" => [ { reward_id: "abc" }, { trader_level: [ "x" ] } ]
  }.freeze

  RESOURCES = {
    "items" => "item", "tasks" => "task", "requirements" => "requirement", "rewards" => "reward",
    "leads_tos" => "leads_to", "previous_tasks" => "previous_task",
    "barter_unlocks" => "barter_unlock", "craft_unlocks" => "craft_unlock",
    "offer_unlocks" => "offer_unlock"
  }.freeze

  test "no admin write route answers 5xx for a malformed payload" do
    offenders = []

    RESOURCES.each do |resource, scope|
      PAYLOADS[scope].each do |payload|
        post_auth "/admin/#{resource}", params: { scope => payload }
        offenders << "POST /admin/#{resource} #{payload.inspect}" if response.status >= 500

        patch_auth "/admin/#{resource}/1", params: { scope => payload }
        offenders << "PATCH /admin/#{resource}/1 #{payload.inspect}" if response.status >= 500
      end
    end

    assert_empty offenders, "5xx responses: #{offenders.join(', ')}"
  end

  test "favorites tolerate malformed and unknown item ids" do
    [ { item_id: [ "1" ] }, { item_id: { "a" => "b" } }, { item_id: "abc" },
      { item_id: "" }, { item_id: "999999999" }, {} ].each do |params|
      post favorites_url, params: params
      assert_response :redirect, "POST /favorites #{params.inspect}"
    end

    [ "abc", "999999999", "1", "1;DROP+TABLE+items" ].each do |id|
      delete favorite_url(item_id: id)
      assert_response :redirect, "DELETE /favorites/#{id}"
    end
  end

  test "an unknown item type falls back instead of raising" do
    post_auth admin_items_path, params: { item: { type: "Bogus", bsg_id: "hostile-type-1",
                                                  full_name: "Hostile Type", short_name: "HT" } }

    assert_response :redirect
    created = Item.find_by(bsg_id: "hostile-type-1")
    assert_equal "Item::Generic", created.type
  ensure
    created&.destroy
  end

  test "an unknown item type on update keeps the existing subclass" do
    item = create_item("Keeps Type", klass: Item::Weapon)

    patch_auth admin_item_path(item), params: { item: { type: "Bogus", full_name: "Keeps Type" } }

    assert_response :redirect
    assert_equal "Item::Weapon", item.reload.type
  ensure
    item&.destroy
  end

  # These three are 4xx in Rails; the catch-all StandardError handler used to
  # intercept them first and report them as 500s.
  test "a missing required param is a 400, not a 500" do
    post_auth admin_items_path, params: { nothing: "here" }

    assert_response :bad_request
  end

  test "a malformed JSON body is a 400, not a 500" do
    post favorites_url, params: "{invalid json", headers: { "Content-Type" => "application/json" }

    assert_response :bad_request
  end

  test "a missing CSRF token is a 422, not a 500" do
    with_forgery_protection do
      post favorites_url, params: { item_id: items(:one).id }

      assert_response :unprocessable_content
    end
  end

  private

  # Forgery protection is off in the test env; turn it on for one request.
  def with_forgery_protection
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    ActionController::Base.allow_forgery_protection = original
  end
end
