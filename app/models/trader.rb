# == Schema Information
#
# Table name: traders
#
#  id          :bigint           not null, primary key
#  bsg_id      :string
#  slug        :string
#  name        :string
#  description :text
#  currency    :string
#  image_url   :string
#  task_count  :integer
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_traders_on_bsg_id  (bsg_id) UNIQUE
#  index_traders_on_slug    (slug) UNIQUE
#
class Trader < ApplicationRecord
  has_many :trader_levels, -> { order(:level) }, dependent: :destroy
end
