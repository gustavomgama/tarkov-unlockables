require "test_helper"

class ItemProvisionTest < ActiveSupport::TestCase
  test "is an STI subclass of Item" do
    assert Item::Provision < Item
  end

  test "persists with type Item::Provision and reloads as Item::Provision" do
    item = Item::Provision.create!(bsg_id: "prov-#{SecureRandom.hex(4)}", full_name: "Emelya Rye", short_name: "Emelya")
    assert_equal "Item::Provision", item.type
    assert_instance_of Item::Provision, Item.find(item.id)
  end
end
