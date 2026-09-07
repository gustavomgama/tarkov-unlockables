require "test_helper"

module Admin
  class ItemsControllerTest < ActionDispatch::IntegrationTest
    def setup
      @item = Item.create!(bsg_id: "test#{SecureRandom.hex(4)}", full_name: "Test Item", short_name: "TI")
      @admin_password = ENV.fetch("ADMIN_PASSWORD") { "admin" }
      @admin_auth = {
        "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", @admin_password)
      }
    end

    def teardown
      @item.destroy if @item
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
      get_auth admin_items_url
      assert_response :success
      assert_select "h1", /Items/i
    end

    test "index displays count" do
      get_auth admin_items_url
      assert_response :success
      assert_match /\(#{Item.count}\)/, response.body
    end

    test "index has new button" do
      get_auth admin_items_url
      assert_response :success
      assert_match /New Item/i, response.body
    end

    test "index displays table headers" do
      get_auth admin_items_url
      assert_response :success
      assert_match /<th[^>]*>ID<\/th>/, response.body
      assert_match /<th[^>]*>BSG ID<\/th>/, response.body
      assert_match /<th[^>]*>Full Name<\/th>/, response.body
      assert_match /<th[^>]*>Short Name<\/th>/, response.body
      assert_match /<th[^>]*>Categories<\/th>/, response.body
    end

    test "index displays resource data" do
      get_auth admin_items_url
      assert_response :success
      assert_match @item.bsg_id, response.body
      assert_match @item.full_name, response.body
    end

    test "get show with auth" do
      get_auth admin_item_url(@item)
      assert_response :success
      assert_match /Test Item/, response.body
    end

    test "show displays all fields" do
      get_auth admin_item_url(@item)
      assert_response :success
      assert_match /BSG ID/, response.body
      assert_match @item.bsg_id, response.body
      assert_match @item.full_name, response.body
      assert_match @item.short_name, response.body
    end

    test "show has edit and delete buttons" do
      get_auth admin_item_url(@item)
      assert_response :success
      assert_match /Edit/i, response.body
      assert_match /Delete/i, response.body
    end

    test "get new with auth" do
      get_auth new_admin_item_url
      assert_response :success
      assert_match /New Item/i, response.body
    end

    test "new form has all fields" do
      get_auth new_admin_item_url
      assert_response :success
      assert_match /name="item\[bsg_id\]"/, response.body
      assert_match /name="item\[full_name\]"/, response.body
      assert_match /name="item\[short_name\]"/, response.body
    end

    test "create with valid params" do
      bsg = "new#{SecureRandom.hex(4)}"
      assert_difference("Item.count") do
        post_auth admin_items_url, params: { item: { bsg_id: bsg, full_name: "New Item", short_name: "NI" } }
      end
      assert_redirected_to admin_item_url(Item.last)
    end

    test "get edit with auth" do
      get_auth edit_admin_item_url(@item)
      assert_response :success
      assert_match /Edit Item/i, response.body
    end

    test "edit form pre-populated with current values" do
      get_auth edit_admin_item_url(@item)
      assert_response :success
      assert_match /Edit Item/, response.body
      assert_match /name="item\[bsg_id\]"/, response.body
      assert_match /value="#{@item.bsg_id}"/, response.body
      assert_match /value="#{@item.full_name}"/, response.body
    end

    test "edit form handles nil categories without error" do
      @item.update_column(:categories, nil)
      @item.update_column(:links, nil)
      @item.update_column(:images, nil)

      get_auth edit_admin_item_url(@item)
      assert_response :success
      refute_match /undefined method/, response.body
    end

    test "update with valid params" do
      original_name = @item.full_name
      patch_auth admin_item_url(@item), params: { item: { full_name: "Updated Name" } }
      assert_redirected_to admin_item_url(@item)
      @item.reload
      assert_equal "Updated Name", @item.full_name
    end

    test "update persists all fields when form is submitted" do
      new_name = "UpdatedItem_#{SecureRandom.hex(4)}"
      patch_auth admin_item_url(@item), params: {
        item: {
          bsg_id: @item.bsg_id,
          slug: @item.slug,
          full_name: new_name,
          short_name: @item.short_name,
          categories: [],
          links: [],
          images: []
        }
      }
      assert_redirected_to admin_item_url(@item)
      @item.reload
      assert_equal new_name, @item.full_name
    end

    test "update bsg_id field" do
      new_bsg_id = "newbsg_#{SecureRandom.hex(4)}"
      patch_auth admin_item_url(@item), params: { item: { bsg_id: new_bsg_id } }
      @item.reload
      assert_equal new_bsg_id, @item.bsg_id
    end

    test "update slug field" do
      new_slug = "new-slug-#{SecureRandom.hex(4)}"
      patch_auth admin_item_url(@item), params: { item: { slug: new_slug } }
      @item.reload
      assert_equal new_slug, @item.slug
    end

    test "update full_name field" do
      new_name = "New Full Name #{SecureRandom.hex(4)}"
      patch_auth admin_item_url(@item), params: { item: { full_name: new_name } }
      @item.reload
      assert_equal new_name, @item.full_name
    end

    test "update short_name field" do
      new_short = "NS#{SecureRandom.hex(2)}"
      patch_auth admin_item_url(@item), params: { item: { short_name: new_short } }
      @item.reload
      assert_equal new_short, @item.short_name
    end

    test "update categories field" do
      new_categories = %w[ammo weapon mod]
      patch_auth admin_item_url(@item), params: { item: { categories: new_categories } }
      @item.reload
      assert_equal new_categories, @item.categories
    end

    test "update links field" do
      new_links = ["https://example.com/1", "https://example.com/2"]
      patch_auth admin_item_url(@item), params: { item: { links: new_links } }
      @item.reload
      assert_equal new_links, @item.links
    end

    test "update images field" do
      new_images = ["https://img.example.com/item1.png", "https://img.example.com/item2.png"]
      patch_auth admin_item_url(@item), params: { item: { images: new_images } }
      @item.reload
      assert_equal new_images, @item.images
    end

    test "update multiple fields at once" do
      patch_auth admin_item_url(@item), params: {
        item: {
          bsg_id: "updated_bsg_#{SecureRandom.hex(4)}",
          slug: "updated-slug-#{SecureRandom.hex(4)}",
          full_name: "Updated Full Name",
          short_name: "UN",
          categories: %w[armor helmet],
          links: ["https://wiki.example.com"],
          images: ["https://img.example.com/updated.png"]
        }
      }
      @item.reload
      assert_equal "updated_bsg_#{@item.bsg_id.split('_').last}", @item.bsg_id
      assert_equal "Updated Full Name", @item.full_name
      assert_equal "UN", @item.short_name
      assert_equal %w[armor helmet], @item.categories
      assert_equal ["https://wiki.example.com"], @item.links
      assert_equal ["https://img.example.com/updated.png"], @item.images
    end

    test "destroy redirects to index" do
      new_item = Item.create!(bsg_id: "del#{SecureRandom.hex(4)}", full_name: "Delete Me", short_name: "DM")
      delete_auth admin_item_url(new_item)
      assert_redirected_to admin_items_url
    end

    test "index requires authentication" do
      get admin_items_url
      assert_response :unauthorized
    end

    test "show requires authentication" do
      get admin_item_url(@item)
      assert_response :unauthorized
    end

    test "new requires authentication" do
      get new_admin_item_url
      assert_response :unauthorized
    end

    test "create requires authentication" do
      post admin_items_url, params: { item: { bsg_id: "x", full_name: "X", short_name: "X" } }
      assert_response :unauthorized
    end

    test "edit requires authentication" do
      get edit_admin_item_url(@item)
      assert_response :unauthorized
    end

    test "update requires authentication" do
      patch admin_item_url(@item), params: { item: { full_name: "X" } }
      assert_response :unauthorized
    end

    test "destroy requires authentication" do
      delete admin_item_url(@item)
      assert_response :unauthorized
    end

    test "show page displays categories without error after update" do
      @item.update!(categories: ["ammo", "weapon"], links: ["https://example.com"], images: ["https://img.com/1.png"])

      patch_auth admin_item_url(@item), params: {
        item: {
          bsg_id: @item.bsg_id,
          full_name: @item.full_name,
          short_name: @item.short_name,
          categories: "mod, armor",
          links: "https://tarkov.dev\nhttps://wiki.com",
          images: "https://img.new/1.png\nhttps://img.new/2.png"
        }
      }

      get_auth admin_item_url(@item)
      assert_response :success
      assert_match /mod, armor/, response.body
      assert_match /tarkov\.dev/, response.body
    end

    test "show page does not throw NoMethodError for array methods" do
      @item.update!(categories: [], links: [], images: [])

      patch_auth admin_item_url(@item), params: {
        item: {
          bsg_id: @item.bsg_id,
          full_name: @item.full_name,
          short_name: @item.short_name,
          categories: "",
          links: "",
          images: ""
        }
      }

      get_auth admin_item_url(@item)
      assert_response :success
    end

    test "show page handles nil categories gracefully" do
      @item.update_column(:categories, nil)

      get_auth admin_item_url(@item)
      assert_response :success
      refute_match /undefined method/, response.body
    end

    # --- Task 9: data JSON, nested obtain attrs, properties/slots gone ---

    test "update item with data JSON string stores it as a hash" do
      payload = '{"caliber":"5.45x39mm","damage":42}'
      patch_auth admin_item_url(@item), params: {
        item: {
          bsg_id: @item.bsg_id,
          full_name: @item.full_name,
          short_name: @item.short_name,
          data: payload
        }
      }
      @item.reload
      assert_equal({ "caliber" => "5.45x39mm", "damage" => 42 }, @item.data)
    end

    test "update item with invalid JSON in data does not save and shows error" do
      original_data = @item.data
      patch_auth admin_item_url(@item), params: {
        item: {
          bsg_id: @item.bsg_id,
          full_name: @item.full_name,
          short_name: @item.short_name,
          data: "{not valid json"
        }
      }
      assert_response :unprocessable_entity
      @item.reload
      assert_equal original_data, @item.data
    end

    test "create item with invalid JSON in data does not save and shows error" do
      bsg = "badjson#{SecureRandom.hex(4)}"
      assert_no_difference("Item.count") do
        post_auth admin_items_url, params: {
          item: { bsg_id: bsg, full_name: "Bad", short_name: "B", data: "{broken" }
        }
      end
      assert_response :unprocessable_entity
    end

    test "update accepts nested item_currencies_attributes and creates rows" do
      assert_difference("@item.item_currencies.count", 1) do
        patch_auth admin_item_url(@item), params: {
          item: {
            bsg_id: @item.bsg_id,
            full_name: @item.full_name,
            short_name: @item.short_name,
            item_currencies_attributes: {
              "0" => { trader: "Prapor", currency: "RUB", min_trader_level: 1 }
            }
          }
        }
      end
      assert_redirected_to admin_item_url(@item)
      ic = @item.item_currencies.last
      assert_equal "Prapor", ic.trader
      assert_equal "RUB", ic.currency
      assert_equal 1, ic.min_trader_level
    end

    test "update accepts nested item_currencies_attributes with _destroy and removes row" do
      ic = @item.item_currencies.create!(trader: "Therapist", currency: "USD", min_trader_level: 2)
      assert_difference("@item.item_currencies.count", -1) do
        patch_auth admin_item_url(@item), params: {
          item: {
            bsg_id: @item.bsg_id,
            full_name: @item.full_name,
            short_name: @item.short_name,
            item_currencies_attributes: {
              "0" => { id: ic.id, _destroy: "1" }
            }
          }
        }
      end
      assert_redirected_to admin_item_url(@item)
      assert_raises(ActiveRecord::RecordNotFound) { ic.reload }
    end

    test "update accepts nested item_barters_attributes and creates row" do
      assert_difference("@item.item_barters.count", 1) do
        patch_auth admin_item_url(@item), params: {
          item: {
            bsg_id: @item.bsg_id,
            full_name: @item.full_name,
            short_name: @item.short_name,
            item_barters_attributes: {
              "0" => { trader: "Therapist", trader_level: "LL2", currency: "USD", cost: 500, item_name: "Barter item" }
            }
          }
        }
      end
    end

    test "update accepts nested item_hideouts_attributes and creates row" do
      assert_difference("@item.item_hideouts.count", 1) do
        patch_auth admin_item_url(@item), params: {
          item: {
            bsg_id: @item.bsg_id,
            full_name: @item.full_name,
            short_name: @item.short_name,
            item_hideouts_attributes: {
              "0" => { station: "Workbench", level: 2 }
            }
          }
        }
      end
    end

    test "update accepts nested item_task_rewards_attributes and creates row" do
      assert_difference("@item.item_task_rewards.count", 1) do
        patch_auth admin_item_url(@item), params: {
          item: {
            bsg_id: @item.bsg_id,
            full_name: @item.full_name,
            short_name: @item.short_name,
            item_task_rewards_attributes: {
              "0" => { task_name: "Debut" }
            }
          }
        }
      end
    end

    test "properties and slots routes are gone (404)" do
      get_auth "/admin/properties"
      assert_response :not_found
      get_auth "/admin/properties/new"
      assert_response :not_found
      get_auth "/admin/slots"
      assert_response :not_found
      get_auth "/admin/slots/new"
      assert_response :not_found
    end

    test "show pretty-prints data as JSON" do
      @item.update!(data: { "caliber" => "7.62x39mm", "damage" => 50 })
      get_auth admin_item_url(@item)
      assert_response :success
      assert_match /7\.62x39mm/, response.body
      assert_match /&quot;caliber&quot;|"caliber"/, response.body
    end

    test "form renders data textarea with current data JSON" do
      @item.update!(data: { "caliber" => "5.45x39mm" })
      get_auth edit_admin_item_url(@item)
      assert_response :success
      assert_match /name="item\[data\]"/, response.body
      assert_match /5\.45x39mm/, response.body
    end

    test "form renders wiki_title and type select" do
      get_auth edit_admin_item_url(@item)
      assert_response :success
      assert_match /name="item\[wiki_title\]"/, response.body
      assert_match /name="item\[type\]"/, response.body
    end

    test "update with type param changes STI class" do
      patch_auth admin_item_url(@item), params: {
        item: {
          bsg_id: @item.bsg_id,
          full_name: @item.full_name,
          short_name: @item.short_name,
          type: "Item::Weapon"
        }
      }
      assert_redirected_to admin_item_url(@item)
      reloaded = Item.find(@item.id)
      assert_equal "Item::Weapon", reloaded.type
      assert_instance_of Item::Weapon, reloaded
    end

    test "update with wiki_title persists" do
      patch_auth admin_item_url(@item), params: {
        item: {
          bsg_id: @item.bsg_id,
          full_name: @item.full_name,
          short_name: @item.short_name,
          wiki_title: "AK-47"
        }
      }
      @item.reload
      assert_equal "AK-47", @item.wiki_title
    end
  end
end
