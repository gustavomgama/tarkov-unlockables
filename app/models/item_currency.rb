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
#  task_id          :bigint
#
# Indexes
#
#  index_item_currencies_on_currency  (currency)
#  index_item_currencies_on_item_id   (item_id)
#  index_item_currencies_on_task_id   (task_id)
#  index_item_currencies_on_trader    (trader)
#
# Foreign Keys
#
#  fk_rails_...  (item_id => items.id)
#  fk_rails_...  (task_id => tasks.id)
#
class ItemCurrency < ApplicationRecord
  belongs_to :item
  # The quest that gates this offer, when canonical knew its id. Nullable:
  # most offers are not task-gated, and the derived index has no task id.
  belongs_to :task, optional: true
end
