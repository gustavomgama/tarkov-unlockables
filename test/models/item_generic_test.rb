require "test_helper"

class ItemGenericTest < ActiveSupport::TestCase
  test "is an STI subclass of Item" do
    assert Item::Generic < Item
  end

  test "persists with type Item::Generic and reloads as Item::Generic" do
    item = Item::Generic.create!(bsg_id: "generic-#{SecureRandom.hex(4)}", full_name: "Generic Item", short_name: "GI")
    assert_equal "Item::Generic", item.type
    assert_instance_of Item::Generic, Item.find(item.id)
  end
end