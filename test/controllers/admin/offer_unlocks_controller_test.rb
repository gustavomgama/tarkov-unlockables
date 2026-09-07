require "test_helper"

module Admin
  class OfferUnlocksControllerTest < ActionDispatch::IntegrationTest
    def setup
      @task = Task.create!(bsg_id: "task#{SecureRandom.hex(4)}", full_name: "Test Task", name: "TT")
      @item = Item.create!(bsg_id: "item#{SecureRandom.hex(4)}", full_name: "Test Item", short_name: "TI")
      @reward = Reward.first || Reward.create!(task_id: @task.id, reward_type: "Item")
      @resource = OfferUnlock.first || OfferUnlock.create!(reward_id: @reward.id, item_id: @item.id, item_name: "Test Item", trader_name: "Prapor", trader_level: 1)
      @admin_password = ENV.fetch("ADMIN_PASSWORD") { "admin" }
      @admin_auth = {
        "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", @admin_password)
      }
    end

    def teardown
    end

    def get_auth(url, **kwargs)
      get url, **kwargs.merge(headers: @admin_auth)
    end

    def post_auth(url, **kwargs)
      post url, **kwargs.merge(headers: @admin_auth)
    end

    def patch_auth(url, **kwargs)
      patch url, **kwargs.merge(headers: @admin_auth)
    end

    def delete_auth(url, **kwargs)
      delete url, **kwargs.merge(headers: @admin_auth)
    end

    test "get index with auth" do
      get_auth admin_offer_unlocks_path
      assert_response :success
      assert_select "h1", /Offer Unlocks/i
    end

    test "index has new button" do
      get_auth admin_offer_unlocks_path
      assert_response :success
      assert_match /New Offer Unlock/i, response.body
    end

    test "get show with auth" do
      get_auth admin_offer_unlock_path(@resource)
      assert_response :success
    end

    test "show has edit and delete buttons" do
      get_auth admin_offer_unlock_path(@resource)
      assert_response :success
      assert_match /Edit/i, response.body
      assert_match /Delete/i, response.body
    end

    test "get new with auth" do
      get_auth new_admin_offer_unlock_path
      assert_response :success
      assert_match /New Offer Unlock/i, response.body
    end

    test "create with valid params" do
      assert_difference("OfferUnlock.count") do
        post_auth admin_offer_unlocks_path, params: { offer_unlock: { reward_id: @reward.id, item_id: @item.id, item_name: "New Offer", trader_name: "Therapist", trader_level: 2 } }
      end
      assert_redirected_to admin_offer_unlock_path(OfferUnlock.last)
    end

    test "get edit with auth" do
      get_auth edit_admin_offer_unlock_path(@resource)
      assert_response :success
      assert_match /Edit Offer Unlock/i, response.body
    end

    test "update with valid params" do
      patch_auth admin_offer_unlock_path(@resource), params: { offer_unlock: { item_name: "Updated Offer" } }
      assert_redirected_to admin_offer_unlock_path(@resource)
    end

    test "destroy redirects to index" do
      new_resource = OfferUnlock.create!(reward_id: @reward.id, item_id: @item.id, item_name: "Test", trader_name: "Prapor", trader_level: 1)
      delete_auth admin_offer_unlock_path(new_resource)
      assert_redirected_to admin_offer_unlocks_path
    end

    test "index requires authentication" do
      get admin_offer_unlocks_path
      assert_response :unauthorized
    end

    test "show requires authentication" do
      get admin_offer_unlock_path(@resource)
      assert_response :unauthorized
    end

    # --- Task 9: item_id as select ---

    test "new form renders item_id as a select with options" do
      get_auth new_admin_offer_unlock_path
      assert_response :success
      assert_match /<select[^>]*name="offer_unlock\[item_id\]"/, response.body
      assert_match /<option[^>]*value="#{@item.id}"/, response.body
    end

    test "edit form renders item_id as a select with selected option" do
      get_auth edit_admin_offer_unlock_path(@resource)
      assert_response :success
      assert_match /<select[^>]*name="offer_unlock\[item_id\]"/, response.body
      assert_match /<option[^>]*selected="selected"[^>]*value="#{@resource.item_id}"|<option[^>]*value="#{@resource.item_id}"[^>]*selected="selected"/, response.body
    end
  end
end
