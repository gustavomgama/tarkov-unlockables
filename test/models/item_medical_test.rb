require "test_helper"

class ItemMedicalTest < ActiveSupport::TestCase
  test "is an STI subclass of Item" do
    assert Item::Medical < Item
  end

  test "persists with type Item::Medical and reloads as Item::Medical" do
    item = Item::Medical.create!(bsg_id: "med-#{SecureRandom.hex(4)}", full_name: "AI-2", short_name: "AI-2")
    assert_equal "Item::Medical", item.type
    assert_instance_of Item::Medical, Item.find(item.id)
  end
end
