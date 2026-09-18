# == Schema Information
#
# Table name: trader_levels
#
#  id                     :bigint           not null, primary key
#  trader_id              :bigint           not null
#  level                  :integer
#  required_player_level  :integer
#  required_reputation    :float
#  required_commerce      :float
#  pay_rate               :float
#  insurance_rate         :float
#  repair_cost_multiplier :float
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_trader_levels_on_trader_id  (trader_id)
#
# Foreign Keys
#
#  fk_rails_...  (trader_id => traders.id)
#
class TraderLevel < ApplicationRecord
  belongs_to :trader
end
