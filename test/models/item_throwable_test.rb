require "test_helper"

class ItemThrowableTest < ActiveSupport::TestCase
  test "is an STI subclass of Item" do
    assert Item::Throwable < Item
  end

  test "persists with type Item::Throwable and reloads as Item::Throwable" do
    item = Item::Throwable.create!(bsg_id: "throw-#{SecureRandom.hex(4)}", full_name: "RGD-5", short_name: "RGD-5")
    assert_equal "Item::Throwable", item.type
    assert_instance_of Item::Throwable, Item.find(item.id)
  end
end
