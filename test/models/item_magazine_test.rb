require "test_helper"

class ItemMagazineTest < ActiveSupport::TestCase
  test "is an STI subclass of Item" do
    assert Item::Magazine < Item
  end

  test "persists with type Item::Magazine and reloads as Item::Magazine" do
    item = Item::Magazine.create!(bsg_id: "mag-#{SecureRandom.hex(4)}", full_name: "30-round mag", short_name: "30rnd")
    assert_equal "Item::Magazine", item.type
    assert_instance_of Item::Magazine, Item.find(item.id)
  end
end
