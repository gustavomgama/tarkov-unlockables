require "test_helper"

module Admin
  class SlotsControllerTest < ActionDispatch::IntegrationTest
    def setup
      @item = Item.first || Item.create!(bsg_id: "test#{SecureRandom.hex(4)}", full_name: "Test Item", short_name: "TI")
      @property = @item.property || Property.create!(item_id: @item.id, properties_type: "ItemPropertiesKey")
      @resource = Slot.first || Slot.create!(property_id: @property.id, name_id: 1, required: false)
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
      get_auth admin_slots_path
      assert_response :success
      assert_select "h1", /Slots/i
    end

    test "index has new button" do
      get_auth admin_slots_path
      assert_response :success
      assert_match /New Slot/i, response.body
    end

    test "get show with auth" do
      get_auth admin_slot_path(@resource)
      assert_response :success
    end

    test "show has edit and delete buttons" do
      get_auth admin_slot_path(@resource)
      assert_response :success
      assert_match /Edit/i, response.body
      assert_match /Delete/i, response.body
    end

    test "get new with auth" do
      get_auth new_admin_slot_path
      assert_response :success
      assert_match /New Slot/i, response.body
    end

    test "create with valid params" do
      assert_difference("Slot.count") do
        post_auth admin_slots_path, params: { slot: { property_id: @property.id, name_id: 1, required: false } }
      end
      assert_redirected_to admin_slot_path(Slot.last)
    end

    test "get edit with auth" do
      get_auth edit_admin_slot_path(@resource)
      assert_response :success
      assert_match /Edit Slot/i, response.body
    end

    test "update with valid params" do
      patch_auth admin_slot_path(@resource), params: { slot: { required: true } }
      assert_redirected_to admin_slot_path(@resource)
    end

    test "destroy redirects to index" do
      new_resource = Slot.create!(property_id: @property.id, name_id: 1, required: false)
      delete_auth admin_slot_path(new_resource)
      assert_redirected_to admin_slots_path
    end

    test "index requires authentication" do
      get admin_slots_path
      assert_response :unauthorized
    end

    test "show requires authentication" do
      get admin_slot_path(@resource)
      assert_response :unauthorized
    end
  end
end
