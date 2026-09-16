# == Schema Information
#
# Table name: maps
#
#  id            :bigint           not null, primary key
#  bsg_id        :string
#  slug          :string
#  name          :string
#  name_id       :string
#  wiki_link     :string
#  description   :text
#  raid_duration :integer
#  players       :string
#  enemies       :jsonb            not null
#  bosses        :jsonb            not null
#  extracts      :jsonb            not null
#  transits      :jsonb            not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_maps_on_bsg_id  (bsg_id) UNIQUE
#  index_maps_on_slug    (slug) UNIQUE
#
class Map < ApplicationRecord
end
