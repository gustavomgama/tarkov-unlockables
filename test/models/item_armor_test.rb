require "test_helper"

class ItemArmorTest < ActiveSupport::TestCase
  test "is an STI subclass of Item" do
    assert Item::Armor < Item
  end

  test "persists with type Item::Armor and reloads as Item::Armor" do
    item = Item::Armor.create!(bsg_id: "armor-#{SecureRandom.hex(4)}", full_name: "PACA", short_name: "PACA")
    assert_equal "Item::Armor", item.type
    assert_instance_of Item::Armor, Item.find(item.id)
  end
end
