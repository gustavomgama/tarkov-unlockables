require "test_helper"

class ArmorControllerTest < ActionDispatch::IntegrationTest
  test "index groups armor by class, toughest first" do
    low = Item::Armor.create!(bsg_id: "ar1-#{SecureRandom.hex(4)}", full_name: "Low Armor", short_name: "LA",
                              data: { "class" => 3, "durability" => 50 })
    high = Item::Armor.create!(bsg_id: "ar2-#{SecureRandom.hex(4)}", full_name: "High Armor", short_name: "HA",
                               data: { "class" => 6, "durability" => 80 })

    get armor_url

    assert_response :success
    assert_select "h1", text: "Armor chart"
    assert_select "h2", text: "Class 6"
    assert_select "h2", text: "Class 3"
    assert_operator response.body.index(item_path(high)), :<, response.body.index(item_path(low))
  ensure
    [ low, high ].each { |i| i&.destroy }
  end
end
