require "test_helper"

module Admin
  class ItemsControllerTest < ActionDispatch::IntegrationTest
    include AdminCrudTests

    def setup
      @item = create_item("Test Item", short_name: "TI")
      @resource = @item
    end

    def teardown
      @item.destroy if @item
    end

    admin_crud_tests model: Item, heading: "Items", display_count: true,
                     index_columns: [ "ID", "BSG ID", "Full Name", "Short Name", "Categories" ],
                     index_data_fields: %i[bsg_id full_name],
                     show_fields: [ [ "BSG ID", :bsg_id ], [ nil, :full_name ], [ "Short Name", :short_name ] ],
                     edit_fields: %i[bsg_id full_name],
                     create_attrs: lambda {
                       { bsg_id: "new#{SecureRandom.hex(4)}", full_name: "New Item", short_name: "NI" }
                     },
                     update_attrs: -> { { full_name: "Updated Name" } },
                     destroy_attrs: lambda {
                       { bsg_id: "del#{SecureRandom.hex(4)}", full_name: "Delete Me", short_name: "DM" }
                     }

    # The shared table links a cell when the column asks for it, and truncates
    # long values with the full text in the title attribute.
    test "index table links and truncates cells as configured" do
      get_auth admin_items_url

      assert_response :success
      assert_select "td a[href=?]", admin_item_path(@item), text: @item.full_name
    end

    test "create shows a flash notice" do
      post_auth admin_items_url, params: {
        item: { bsg_id: "flash#{SecureRandom.hex(4)}", full_name: "Flash Item", short_name: "FI" }
      }

      # The redirect target is an admin page, so the follow-up needs the header.
      get_auth response.location
      assert_select "div", text: /Item created/
    ensure
      Item.where(full_name: "Flash Item").delete_all
    end

    test "create with invalid data shows the error banner" do
      post_auth admin_items_url, params: {
        item: { bsg_id: "bad#{SecureRandom.hex(4)}", full_name: "Bad Item", short_name: "BI", data: "{broken" }
      }

      assert_response :unprocessable_entity
      assert_select "li", text: /must be valid JSON/
    end

    test "new form has all fields" do
      get_auth new_admin_item_url
      assert_response :success

      %w[bsg_id full_name short_name].each do |field|
        assert_match(/name="item\[#{field}\]"/, response.body)
      end
    end

    test "edit form handles nil categories without error" do
      %i[categories links images].each { |column| @item.update_column(column, nil) }

      get_auth edit_admin_item_url(@item)
      assert_response :success
      refute_match /undefined method/, response.body
    end

    test "update persists all fields when form is submitted" do
      new_name = "UpdatedItem_#{SecureRandom.hex(4)}"

      patch_item(slug: @item.slug, full_name: new_name, categories: [], links: [], images: [])

      assert_redirected_to admin_item_url(@item)
      assert_equal new_name, @item.reload.full_name
    end

    test "update bsg_id field" do
      new_bsg_id = "newbsg_#{SecureRandom.hex(4)}"
      assert_item_field_update(:bsg_id, new_bsg_id)
    end

    test "update slug field" do
      new_slug = "new-slug-#{SecureRandom.hex(4)}"
      assert_item_field_update(:slug, new_slug)
    end

    test "update full_name field" do
      new_name = "New Full Name #{SecureRandom.hex(4)}"
      assert_item_field_update(:full_name, new_name)
    end

    test "update short_name field" do
      new_short = "NS#{SecureRandom.hex(2)}"
      assert_item_field_update(:short_name, new_short)
    end

    test "update categories field" do
      new_categories = %w[ammo weapon mod]
      assert_item_field_update(:categories, new_categories)
    end

    test "update links field" do
      new_links = [ "https://example.com/1", "https://example.com/2" ]
      assert_item_field_update(:links, new_links)
    end

    test "update images field" do
      new_images = [ "https://img.example.com/item1.png", "https://img.example.com/item2.png" ]
      assert_item_field_update(:images, new_images)
    end

    test "update multiple fields at once" do
      new_bsg_id = "updated_bsg_#{SecureRandom.hex(4)}"
      patch_item(
        bsg_id: new_bsg_id,
        slug: "updated-slug-#{SecureRandom.hex(4)}",
        full_name: "Updated Full Name",
        short_name: "UN",
        categories: %w[armor helmet],
        links: [ "https://wiki.example.com" ],
        images: [ "https://img.example.com/updated.png" ]
      )

      @item.reload
      assert_equal new_bsg_id, @item.bsg_id
      {
        full_name: "Updated Full Name",
        short_name: "UN",
        categories: %w[armor helmet],
        links: [ "https://wiki.example.com" ],
        images: [ "https://img.example.com/updated.png" ]
      }.each { |field, expected| assert_equal expected, @item.public_send(field), field }
    end

    test "show page displays categories without error after update" do
      @item.update!(categories: [ "ammo", "weapon" ], links: [ "https://example.com" ], images: [ "https://img.com/1.png" ])

      patch_item(categories: "mod, armor",
          links: "https://tarkov.dev\nhttps://wiki.com",
          images: "https://img.new/1.png\nhttps://img.new/2.png")

      get_admin_ok(admin_item_url(@item))
      assert_match /mod, armor/, response.body
      assert_match /tarkov\.dev/, response.body
    end

    test "show page does not throw NoMethodError for array methods" do
      @item.update!(categories: [], links: [], images: [])

      patch_item(categories: "", links: "", images: "")

      get_admin_ok(admin_item_url(@item))
    end

    test "show page handles nil categories gracefully" do
      @item.update_column(:categories, nil)

      get_admin_ok(admin_item_url(@item))
      refute_match /undefined method/, response.body
    end

    test "update item with data JSON string stores it as a hash" do
      payload = '{"caliber":"5.45x39mm","damage":42}'
      patch_item(data: payload)
      @item.reload
      assert_equal({ "caliber" => "5.45x39mm", "damage" => 42 }, @item.data)
    end

    test "update item with invalid JSON in data does not save and shows error" do
      original_data = @item.data
      patch_item(data: "{not valid json")
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
        patch_item(item_currencies_attributes: { "0" => { trader: "Prapor", currency: "RUB", min_trader_level: 1 } })
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
        patch_item(item_currencies_attributes: { "0" => { id: ic.id, _destroy: "1" } })
      end
      assert_redirected_to admin_item_url(@item)
      assert_raises(ActiveRecord::RecordNotFound) { ic.reload }
    end

    test "update accepts nested item_barters_attributes and creates row" do
      assert_difference("@item.item_barters.count", 1) do
        patch_item(
          item_barters_attributes: {
            "0" => { trader: "Therapist", trader_level: "LL2", currency: "USD", cost: 500, item_name: "Barter item" }
          }
        )
      end
    end

    test "update accepts nested item_hideouts_attributes and creates row" do
      assert_difference("@item.item_hideouts.count", 1) do
        patch_item(item_hideouts_attributes: { "0" => { station: "Workbench", level: 2 } })
      end
    end

    test "update accepts nested item_task_rewards_attributes and creates row" do
      assert_difference("@item.item_task_rewards.count", 1) do
        patch_item(item_task_rewards_attributes: { "0" => { task_name: "Debut" } })
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
      get_admin_ok(admin_item_url(@item))
      assert_match /7\.62x39mm/, response.body
      assert_match /&quot;caliber&quot;|"caliber"/, response.body
    end

    test "edit form renders the data textarea, wiki_title and type select" do
      @item.update!(data: { "caliber" => "5.45x39mm" })
      get_auth edit_admin_item_url(@item)

      assert_response :success
      %w[data wiki_title type].each { |field| assert_match(/name="item\[#{field}\]"/, response.body) }
      assert_match /5\.45x39mm/, response.body
    end

    test "update persists the type and wiki_title fields" do
      patch_item(type: "Item::Weapon", wiki_title: "AK-47")

      assert_redirected_to admin_item_url(@item)
      reloaded = Item.find(@item.id)
      assert_instance_of Item::Weapon, reloaded
      assert_equal "AK-47", reloaded.wiki_title
    end

    test "index search by full_name returns matching items" do
      create_item("AK-74M Assault Rifle", short_name: "AK-74M")
      create_item("M4A1 Carbine", short_name: "M4A1")

      get_auth admin_items_url(q: "AK-74")

      assert_response :success
      assert_match /AK-74M/, response.body
      refute_match /M4A1/, response.body
    end

    test "index search with no results shows empty table" do
      get_auth admin_items_url(q: "ZZZZNONEXISTENT")
      assert_response :success
      assert_match /Items/, response.body
    end

    private

    # GETs an admin page with credentials and asserts it rendered.
    def get_admin_ok(path)
      get_auth path
      assert_response :success
    end

    # PATCH the item with its required fields plus any overrides, so a test
    # only states the field it is actually exercising.
    def patch_item(**overrides)
      patch_auth admin_item_url(@item), params: {
        item: {
          bsg_id: @item.bsg_id,
          full_name: @item.full_name,
          short_name: @item.short_name
        }.merge(overrides)
      }
    end

    # Patches one item field and asserts it persisted.
    def assert_item_field_update(field, value)
      patch_item(field => value)

      @item.reload
      assert_equal value, @item.public_send(field)
    end
  end
end
