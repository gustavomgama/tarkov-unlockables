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
#  craft_id   :string
#  count      :integer          default(1), not null
#  duration   :integer
#  task_id    :bigint
#
# Indexes
#
#  index_item_hideouts_on_craft_id  (craft_id)
#  index_item_hideouts_on_item_id   (item_id)
#  index_item_hideouts_on_task_id   (task_id)
#
# Foreign Keys
#
#  fk_rails_...  (item_id => items.id)
#  fk_rails_...  (task_id => tasks.id)
#
class ItemHideout < ApplicationRecord
  belongs_to :item
  belongs_to :task, optional: true
  has_many :item_hideout_requirements, dependent: :destroy
end
