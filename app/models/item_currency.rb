# == Schema Information
#
# Table name: item_currencies
#
#  id               :bigint           not null, primary key
#  item_id          :bigint           not null
#  trader           :string
#  currency         :string
#  min_trader_level :integer
#  task_unlock      :boolean          default(FALSE), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_item_currencies_on_item_id  (item_id)
#
# Foreign Keys
#
#  fk_rails_...  (item_id => items.id)
#
class ItemCurrency < ApplicationRecord
  belongs_to :item
end
