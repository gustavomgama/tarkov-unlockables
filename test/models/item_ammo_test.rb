require "test_helper"

class ItemAmmoTest < ActiveSupport::TestCase
  test "is an STI subclass of Item" do
    assert Item::Ammo < Item
  end

  test "persists with type Item::Ammo and reloads as Item::Ammo" do
    item = Item::Ammo.create!(bsg_id: "ammo-#{SecureRandom.hex(4)}", full_name: "5.45x39 PS", short_name: "PS")
    assert_equal "Item::Ammo", item.type
    assert_instance_of Item::Ammo, Item.find(item.id)
  end
end
