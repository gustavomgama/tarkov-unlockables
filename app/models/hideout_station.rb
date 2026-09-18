# == Schema Information
#
# Table name: hideout_stations
#
#  id         :bigint           not null, primary key
#  bsg_id     :string
#  slug       :string
#  name       :string
#  image_url  :string
#  area_type  :integer
#  position   :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_hideout_stations_on_bsg_id  (bsg_id) UNIQUE
#  index_hideout_stations_on_slug    (slug) UNIQUE
#
class HideoutStation < ApplicationRecord
  has_many :hideout_levels, -> { order(:level) }, dependent: :destroy
end
