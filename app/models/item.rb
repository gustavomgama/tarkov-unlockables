# == Schema Information
#
# Table name: items
#
#  id         :bigint           not null, primary key
#  type       :string           default("Item::Generic"), not null
#  bsg_id     :string
#  slug       :string
#  full_name  :string
#  short_name :string
#  wiki_title :string
#  categories :text             default([]), is an Array
#  links      :text             default([]), is an Array
#  images     :text             default([]), is an Array
#  data       :jsonb            not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_items_on_bsg_id  (bsg_id) UNIQUE
#  index_items_on_slug    (slug)
#  index_items_on_type    (type)
#
class Item < ApplicationRecord
  has_many :item_task_rewards, dependent: :destroy
  has_many :item_hideouts, dependent: :destroy
  has_many :item_barters, dependent: :destroy
  has_many :item_currencies, dependent: :destroy

  scope :task_gated, -> { none }
end
