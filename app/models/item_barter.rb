# == Schema Information
#
# Table name: item_barters
#
#  id           :bigint           not null, primary key
#  item_id      :bigint           not null
#  trader       :string
#  trader_level :string
#  currency     :string
#  cost         :integer
#  item_name    :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_item_barters_on_item_id  (item_id)
#
# Foreign Keys
#
#  fk_rails_...  (item_id => items.id)
#
class ItemBarter < ApplicationRecord
  belongs_to :item
end
