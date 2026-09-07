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

  TYPE_MAP = {
    "Weapon" => "Item::Weapon",
    "Ammo" => "Item::Ammo",
    "Armor" => "Item::Armor",
    "Key" => "Item::Key",
    "Magazine" => "Item::Magazine",
    "Container" => "Item::Container",
    "MedKit" => "Item::Medical",
    "Medical" => "Item::Medical",
    "FoodDrink" => "Item::Provision",
    "Provision" => "Item::Provision",
    "Grenade" => "Item::Throwable",
    "Throwable" => "Item::Throwable"
  }.freeze

  def self.type_for(properties_type, wiki_infobox = nil)
    # source uses "ItemPropertiesWeapon" — strip the prefix; wiki infobox wins
    base = wiki_infobox.to_s.camelize
    base = properties_type.to_s.sub(/\AItemProperties/, "") if base.blank?
    (TYPE_MAP[base] || "Item::Generic").constantize
  end

  def data=(value)
    super(value.is_a?(String) ? JSON.parse(value) : value)
  rescue JSON::ParserError
    errors.add(:data, "must be valid JSON")
    super({})
  end

  # --- obtain graph (uses internal id) ---

  ObtainEntry = Struct.new(:type, :source, keyword_init: true)
  UnlockPath = Struct.new(:task, :reward_type, :unlock_method, keyword_init: true)

  def obtain_from
    entries = []
    item_task_rewards.find_each { |r| entries << ObtainEntry.new(type: :task_reward, source: r) }
    item_hideouts.find_each { |r| entries << ObtainEntry.new(type: :hideout, source: r) }
    item_barters.find_each { |r| entries << ObtainEntry.new(type: :barter, source: r) }
    item_currencies.find_each { |r| entries << ObtainEntry.new(type: :currency, source: r) }
    entries
  end

  def obtain_types
    obtain_from.map(&:type).uniq
  end

  def obtain_from_tasks
    obtain_from.select { |e| e.type == :task_reward }
  end

  def obtain_from_hideouts
    obtain_from.select { |e| e.type == :hideout }
  end

  def obtain_from_barters
    obtain_from.select { |e| e.type == :barter }
  end

  def obtain_from_currencies
    obtain_from.select { |e| e.type == :currency }
  end

  def requires_task?
    %w[OfferUnlock BarterUnlock CraftUnlock].any? do |model_name|
      model_name.constantize.exists?(item_id: id)
    end
  end

  scope :task_gated, -> {
    where(id: [ OfferUnlock.pluck(:item_id), BarterUnlock.pluck(:item_id), CraftUnlock.pluck(:item_id) ].flatten.uniq)
  }

  def self.search(query)
    return all if query.blank?
    q = "%#{query}%"
    where("slug ILIKE ? OR full_name ILIKE ? OR short_name ILIKE ?", q, q, q)
  end

  def how_to_unlock
    paths = []
    Reward.joins(:offer_unlocks).where(offer_unlocks: { item_id: id }).find_each do |reward|
      paths << UnlockPath.new(task: reward.task, reward_type: reward.reward_type, unlock_method: :offer_unlock)
    end
    Reward.joins(:barter_unlocks).where(barter_unlocks: { item_id: id }).find_each do |reward|
      paths << UnlockPath.new(task: reward.task, reward_type: reward.reward_type, unlock_method: :barter_unlock)
    end
    Reward.joins(:craft_unlocks).where(craft_unlocks: { item_id: id }).find_each do |reward|
      paths << UnlockPath.new(task: reward.task, reward_type: reward.reward_type, unlock_method: :craft_unlock)
    end
    paths.uniq
  end

  def unlock_details_for(path)
    reward = path.task.rewards.where(reward_type: path.reward_type).first
    return nil unless reward

    case path.unlock_method
    when :craft_unlock
      craft_unlock = reward.craft_unlocks.where(item_id: id).first
      return nil unless craft_unlock
      details = []
      details << "Craft at #{craft_unlock.hideout_station} Level #{craft_unlock.station_level}"
      craft_unlock.craft_requirements.each do |req|
        next if req.trader_level.blank?
        details << "Requires #{req.trader_name.titleize} LL#{req.trader_level}"
      end
      craft_unlock.craft_requirements.flat_map(&:craft_requirement_items).each do |item|
        details << "#{item.item_name} x#{item.count}"
      end
      details.join(" · ")
    when :barter_unlock
      barter_unlock = reward.barter_unlocks.where(item_id: id).first
      return nil unless barter_unlock
      details = []
      barter_unlock.barter_requirements.each do |req|
        details << "#{req.trader_name.titleize} LL#{req.trader_level}"
      end
      items = barter_unlock.barter_results.flat_map(&:barter_result_items).map(&:item_name)
      details << "Gives: #{items.join(", ")}" if items.any?
      barter_unlock.barter_requirements.flat_map(&:barter_requirement_items).each do |item|
        details << "#{item.item_name} x#{item.count}"
      end
      details.join(" · ")
    when :offer_unlock
      offer_unlock = reward.offer_unlocks.where(item_id: id).first
      return nil unless offer_unlock
      "#{offer_unlock.trader_name.titleize} LL#{offer_unlock.trader_level}"
    else
      nil
    end
  end
end
