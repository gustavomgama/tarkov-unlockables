require "test_helper"

class ArmorControllerTest < ActionDispatch::IntegrationTest
  test "index groups body armor and helmets by class, toughest first" do
    low = Item::Armor.create!(bsg_id: "ar1-#{SecureRandom.hex(4)}", full_name: "Low Armor", short_name: "LA",
                              data: { "class" => 3, "durability" => 50 })
    high = Item::Armor.create!(bsg_id: "ar2-#{SecureRandom.hex(4)}", full_name: "High Armor", short_name: "HA",
                               data: { "class" => 6, "durability" => 80 })
    helmet = Item.create!(bsg_id: "ar3-#{SecureRandom.hex(4)}", full_name: "Test Helmet", short_name: "TH",
                          data: { "propertiesType" => "ItemPropertiesHelmet", "class" => 4, "durability" => 40 })

    get armor_url

    assert_response :success
    assert_select "h1", text: "Armor chart"
    assert_select "h2", text: "Body armor class 6"
    assert_select "h2", text: "Body armor class 3"
    assert_select "h2", text: "Helmet class 4"
    assert_select "a[href=?]", item_path(helmet), text: "Test Helmet"
    assert_select "a[href=?]", ammo_path(min_class: 6), text: "Rounds that pen it"
    assert_operator response.body.index(item_path(high)), :<, response.body.index(item_path(low))
  ensure
    [ low, high, helmet ].each { |i| i&.destroy }
  end
end
