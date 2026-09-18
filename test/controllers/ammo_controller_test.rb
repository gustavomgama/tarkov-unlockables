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

    # "Pens class 4+" keeps the strong round and drops the weak one.
    get ammo_url(min_class: 4)
    assert_response :success
    assert_match item_path(strong), response.body
    assert_no_match item_path(weak), response.body

    # Nothing in this caliber defeats class 6.
    get ammo_url(min_class: 6)
    assert_response :success
    assert_no_match item_path(strong), response.body
  ensure
    [ weak, strong ].each { |i| i&.destroy }
  end

  # The chart's effectiveness levels are the rule where a round has them, even
  # when its penetration would put it two classes lower.
  test "min_class follows the wiki levels, not the penetration estimate" do
    charted = Item::Ammo.create!(
      bsg_id: "am3-#{SecureRandom.hex(4)}", full_name: "Charted Round", short_name: "CR",
      armor_class_effectiveness: { "1" => 6, "2" => 6, "3" => 6, "4" => 4, "5" => 3, "6" => 0 },
      data: { "caliber" => "Caliber556x45NATO", "penetration_power" => 24, "damage" => 40 }
    )

    get ammo_url(min_class: 4)
    assert_response :success
    assert_match item_path(charted), response.body

    get ammo_url(min_class: 5)
    assert_response :success
    assert_no_match item_path(charted), response.body
  ensure
    charted&.destroy
  end
end
