require "test_helper"

# == Schema Information
#
# Table name: item_hideouts
#
#  id         :bigint           not null, primary key
#  item_id    :bigint           not null
#  station    :string
#  level      :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_item_hideouts_on_item_id  (item_id)
#
# Foreign Keys
#
#  fk_rails_...  (item_id => items.id)
#
class ItemHideoutTest < ActiveSupport::TestCase
  test "belongs to item" do
    item = Item.create!(bsg_id: "ih-#{SecureRandom.hex(4)}", full_name: "IH", short_name: "IH")
    ih = item.item_hideouts.create!(station: "Workbench", level: 1)
    assert_equal item, ih.item
  end

  test "requires an item" do
    assert_raises(ActiveRecord::RecordInvalid) do
      ItemHideout.create!(station: "Workbench", level: 1)
    end
  end
end
