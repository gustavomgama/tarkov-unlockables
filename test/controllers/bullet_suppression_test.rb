# frozen_string_literal: true

require "test_helper"

class BulletSuppressionTest < ActionDispatch::IntegrationTest
  # Bullet flags offer_unlocks as an unused eager load on Item::Ammo (ammo
  # rarely has task unlocks). The suppression must live in Bullet's config
  # safelist — not in a runtime toggle inside the controller.
  test "ammo show page does not raise Bullet UnoptimizedQueryError" do
    ammo = Item::Ammo.create!(
      bsg_id: "bullet-ammo-#{SecureRandom.hex(4)}",
      full_name: "Bullet Test Ammo",
      short_name: "BTA",
      data: { "caliber" => "9x19mm Parabellum" }
    )
    get item_url(ammo)
    assert_response :success
  ensure
    ammo&.destroy
  end

  test "items#show does not modify Bullet.enable state" do
    original = Bullet.enable?
    item = Item.first || Item.create!(bsg_id: "bs-#{SecureRandom.hex(4)}", full_name: "B Item", short_name: "BI")
    get item_url(item)
    assert_response :success
    assert_equal original, Bullet.enable?, "items#show mutated Bullet.enable — use config-level safelist instead"
  end
end
