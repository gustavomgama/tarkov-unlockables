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
class ItemHideout < ApplicationRecord
  belongs_to :item
end
