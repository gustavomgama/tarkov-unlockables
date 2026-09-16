# == Schema Information
#
# Table name: hideout_levels
#
#  id                   :bigint           not null, primary key
#  hideout_station_id   :bigint           not null
#  level                :integer
#  construction_time    :integer
#  station_requirements :jsonb            not null
#  trader_requirements  :jsonb            not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
# Indexes
#
#  index_hideout_levels_on_hideout_station_id  (hideout_station_id)
#
# Foreign Keys
#
#  fk_rails_...  (hideout_station_id => hideout_stations.id)
#
class HideoutLevel < ApplicationRecord
  belongs_to :hideout_station
  has_many :hideout_item_requirements, dependent: :destroy
end
