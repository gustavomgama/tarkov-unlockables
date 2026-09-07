require "test_helper"

class ItemContainerTest < ActiveSupport::TestCase
  test "is an STI subclass of Item" do
    assert Item::Container < Item
  end

  test "persists with type Item::Container and reloads as Item::Container" do
    item = Item::Container.create!(bsg_id: "cont-#{SecureRandom.hex(4)}", full_name: "Scav Backpack", short_name: "Scav BP")
    assert_equal "Item::Container", item.type
    assert_instance_of Item::Container, Item.find(item.id)
  end
end