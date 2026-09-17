require "test_helper"

class AmmoControllerTest < ActionDispatch::IntegrationTest
  test "index lists rounds by caliber, penetration first" do
    weak = Item::Ammo.create!(bsg_id: "am1-#{SecureRandom.hex(4)}", full_name: "Weak Round", short_name: "WR",
                              data: { "caliber" => "Caliber556x45NATO", "penetration_power" => 10, "damage" => 40 })
    strong = Item::Ammo.create!(bsg_id: "am2-#{SecureRandom.hex(4)}", full_name: "Strong Round", short_name: "SR",
                                data: { "caliber" => "Caliber556x45NATO", "penetration_power" => 44, "damage" => 49 })

    get ammo_url

    assert_response :success
    assert_select "h1", text: "Ammo chart"
    assert_operator response.body.index(item_path(strong)), :<, response.body.index(item_path(weak))
  ensure
    [ weak, strong ].each { |i| i&.destroy }
  end
end
