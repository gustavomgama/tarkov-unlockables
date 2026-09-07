require "test_helper"

class ItemKeyTest < ActiveSupport::TestCase
  test "is an STI subclass of Item" do
    assert Item::Key < Item
  end

  test "persists with type Item::Key and reloads as Item::Key" do
    item = Item::Key.create!(bsg_id: "key-#{SecureRandom.hex(4)}", full_name: "Factory Key", short_name: "FK")
    assert_equal "Item::Key", item.type
    assert_instance_of Item::Key, Item.find(item.id)
  end
end
