# == Schema Information
#
# Table name: item_barters
#
#  id             :bigint           not null, primary key
#  item_id        :bigint           not null
#  trader         :string
#  trader_level   :string
#  currency       :string
#  cost           :integer
#  item_name      :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  barter_id      :string
#  count          :integer          default(1), not null
#  buy_limit      :integer
#  restock_amount :bigint
#  task_id        :bigint
#
# Indexes
#
#  index_item_barters_on_barter_id  (barter_id)
#  index_item_barters_on_item_id    (item_id)
#  index_item_barters_on_task_id    (task_id)
#
# Foreign Keys
#
#  fk_rails_...  (item_id => items.id)
#  fk_rails_...  (task_id => tasks.id)
#
class ItemBarter < ApplicationRecord
  belongs_to :item
  belongs_to :task, optional: true
  has_many :item_barter_requirements, dependent: :destroy
end
