require "test_helper"

class ItemWeaponTest < ActiveSupport::TestCase
  test "is an STI subclass of Item" do
    assert Item::Weapon < Item
  end

  test "persists with type Item::Weapon and reloads as Item::Weapon" do
    item = Item::Weapon.create!(bsg_id: "weapon-#{SecureRandom.hex(4)}", full_name: "AK-74M", short_name: "AK-74M")
    assert_equal "Item::Weapon", item.type
    assert_instance_of Item::Weapon, Item.find(item.id)
  end
end
