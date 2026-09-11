# == Schema Information
#
# Table name: items
#
#  id          :bigint           not null, primary key
#  type        :string           default("Item::Generic"), not null
#  bsg_id      :string
#  slug        :string
#  full_name   :string
#  short_name  :string
#  wiki_title  :string
#  categories  :text             default([]), is an Array
#  links       :text             default([]), is an Array
#  images      :text             default([]), is an Array
#  data        :jsonb            not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  search_text :string           default(""), not null
#
# Indexes
#
#  index_items_on_bsg_id            (bsg_id) UNIQUE
#  index_items_on_categories        (categories) USING gin
#  index_items_on_data              (data) USING gin
#  index_items_on_full_name         (full_name)
#  index_items_on_search_text_trgm  (search_text) USING gin
#  index_items_on_slug              (slug)
#  index_items_on_type              (type)
#
class Item < ApplicationRecord
  has_many :item_task_rewards, dependent: :delete_all
  has_many :item_hideouts, dependent: :delete_all
  has_many :item_barters, dependent: :delete_all
  has_many :item_currencies, dependent: :delete_all
  has_many :loose_items, dependent: :delete_all
  has_many :offer_unlocks, dependent: :delete_all
  has_many :barter_unlocks, dependent: :delete_all
  has_many :craft_unlocks, dependent: :delete_all
  has_many :barter_requirement_items, dependent: :delete_all
  has_many :barter_result_items, dependent: :delete_all
  has_many :craft_requirement_items, dependent: :delete_all
  has_many :craft_result_items, dependent: :delete_all

  attr_accessor :data_json_invalid

  accepts_nested_attributes_for :item_currencies, :item_task_rewards, :item_hideouts, :item_barters,
                                allow_destroy: true, reject_if: :all_blank

  validate :data_json_must_be_valid

  # Keeps the trigram-indexed search_text column fresh for loose_search.
  before_validation :set_search_text

  def set_search_text
    self.search_text = "#{full_name} #{short_name}".gsub(/[^a-zA-Z0-9]/, "").downcase
  end

  def data_json_must_be_valid
    errors.add(:data, "must be valid JSON") if @data_json_invalid
  end

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

  CALIBER_MAP = {
    "Caliber1143x23ACP" => ".45 ACP",
    "Caliber127x33" => ".50 AE",
    "Caliber127x55" => "12.7x55mm",
    "Caliber127x99" => ".50 BMG",
    "Caliber12g" => "12/70",
    "Caliber20g" => "20/70",
    "Caliber20x1mm" => "20x1mm",
    "Caliber23x75" => "23x75mm",
    "Caliber26x75" => "26x75mm",
    "Caliber366TKM" => ".366 TKM",
    "Caliber40mmRU" => "40mm RU",
    "Caliber40x46" => "40x46mm",
    "Caliber46x30" => "4.6x30mm",
    "Caliber545x39" => "5.45x39mm",
    "Caliber556x45NATO" => "5.56x45mm NATO",
    "Caliber57x28" => "5.7x28mm",
    "Caliber58x42" => "5.8x42mm",
    "Caliber68x51" => "6.8x51mm",
    "Caliber762x25TT" => "7.62x25mm TT",
    "Caliber762x35" => ".300 Blackout",
    "Caliber762x39" => "7.62x39mm",
    "Caliber762x51" => "7.62x51mm NATO",
    "Caliber762x54R" => "7.62x54mmR",
    "Caliber784x49" => ".308 ME",
    "Caliber86x70" => ".338 Lapua Magnum",
    "Caliber93x64" => "9.3x64mm",
    "Caliber9x18PM" => "9x18mm PM",
    "Caliber9x19PARA" => "9x19mm Parabellum",
    "Caliber9x21" => "9x21mm Gyurza",
    "Caliber9x33R" => ".357 Magnum",
    "Caliber9x39" => "9x39mm"
  }.freeze

  def self.caliber_display(raw)
    return raw if raw.blank?
    CALIBER_MAP.fetch(raw) { raw }
  end

  # Caliber patterns for parsing names/slugs of guns and presets that lack
  # data->>'caliber'. Ordered longest-first so "7.62x51" wins over "62x5".
  CALIBER_NAME_PATTERNS = {
    ".300 Blackout" => [ "300 blackout", "300blackout", "762x35" ],
    ".308 ME" => [ "308 me", "308 marlin" ],
    ".338 Lapua Magnum" => [ "338 lapua", "338lm" ],
    ".357 Magnum" => [ "357 magnum", "357mag" ],
    ".366 TKM" => [ "366 tkm", "366tkm" ],
    ".45 ACP" => [ "45 acp", "45acp" ],
    ".50 AE" => [ "50 ae", "50ae" ],
    ".50 BMG" => [ "50 bmg", "50bmg" ],
    "12.7x55mm" => [ "12.7x55", "127x55" ],
    "12/70" => [ "12x70", "12ga", "12/70" ],
    "20/70" => [ "20x70", "20ga", "20/70" ],
    "23x75mm" => [ "23x75" ],
    "26x75mm" => [ "26x75" ],
    "4.6x30mm" => [ "4.6x30", "46x30" ],
    "40x46mm" => [ "40x46" ],
    "40x53mm" => [ "40x53" ],
    "5.45x39mm" => [ "5.45x39", "545x39" ],
    "5.56x45mm NATO" => [ "5.56x45", "556x45" ],
    "5.7x28mm FN" => [ "5.7x28", "57x28" ],
    "5.8x42mm" => [ "5.8x42", "58x42" ],
    "6.8x51mm" => [ "6.8x51", "68x51" ],
    "7.62x25mm Tokarev" => [ "7.62x25", "762x25" ],
    "7.62x39mm" => [ "7.62x39", "762x39" ],
    "7.62x51mm NATO" => [ "7.62x51", "762x51" ],
    "7.62x54mmR" => [ "7.62x54", "762x54" ],
    "9.3x64mm" => [ "9.3x64", "93x64" ],
    "9x18mm Makarov" => [ "9x18", "9x18pm" ],
    "9x19mm Parabellum" => [ "9x19", "9x19para" ],
    "9x21mm Gyurza" => [ "9x21" ],
    "9x39mm" => [ "9x39" ]
  }.freeze

  # Parses a caliber display name from an item name or slug.
  # Tolerates missing dots, case differences ("9X19" vs "9x19"), and
  # slug separators. Returns nil when no caliber is recognizable.
  def self.parse_caliber_from_name(name)
    return nil if name.blank?

    normalized = name.to_s.downcase.gsub(/[^a-z0-9]+/, "")
    CALIBER_NAME_PATTERNS.each do |display, patterns|
      patterns.each do |pattern|
        return display if normalized.include?(pattern.gsub(/[^a-z0-9]/, ""))
      end
    end
    nil
  end

  # Backfills data['caliber'] for items (presets, guns) whose caliber only
  # appears in their name. Never overwrites an existing caliber value.
  def self.populate_calibers_from_names
    Item.where("data->>'caliber' IS NULL").find_each do |item|
      caliber = parse_caliber_from_name(item.full_name) ||
                parse_caliber_from_name(item.slug) ||
                parse_caliber_from_name(item.wiki_title)
      next if caliber.blank?

      item.update_column(:data, (item.data || {}).merge("caliber" => caliber))
    end
  end

  # Maps caliber display name → matching category bases (excludes _pack/_box/_bundle).
  # Computed on demand (not at class load) so boot never touches the DB and
  # re-imported data is reflected immediately.
  def self.caliber_category_map
    Rails.cache.fetch("items/caliber_category_map", expires_in: 1.hour) do
      build_caliber_category_map
    end
  end

  # Full category list backing filter expansion. Cached: changes only on import.
  def self.category_list
    Rails.cache.fetch("items/category_list", expires_in: 1.hour) do
      pluck(:categories).flatten.uniq
    end
  end

  def self.build_caliber_category_map
    # Normalize: lowercase, strip non-alphanumeric, strip 'x', strip trailing 'mm'
    norm = ->(s) { s.downcase.gsub(/[^a-zA-Z0-9]/, "").gsub("x", "").sub(/mm\z/, "") }

    all_cats = category_list
    cal_bases = all_cats.map { |c| c.sub(/_(pack|box|bundle)\z/, "") }
                        .uniq.select { |b| b =~ /^\d/ || b =~ /^\./ }

    raw_calibers = Item.distinct.pluck(Arel.sql("data->>'caliber'")).compact
    display_to_cats = {}
    raw_calibers.each do |raw|
      display = Item.caliber_display(raw)
      next if display.start_with?("Caliber")
      next if display_to_cats.key?(display)
      dn = norm.call(display)
      display_to_cats[display] = cal_bases.select { |b|
        bn = norm.call(b)
        bn == dn || bn.start_with?(dn) || dn.start_with?(bn)
      }
    end
    display_to_cats
  end

  # All category bases that are caliber-like (matched by any caliber)
  def self.caliber_category_bases
    caliber_category_map.values.flatten.uniq
  end

  def ammo_packs
    return Item.none unless bsg_id.present?
    Item.where(type: "Item::Generic")
        .where("data->'containsItems' @> ?", [ { "item" => bsg_id } ].to_json)
  end

  def self.type_for(properties_type, wiki_infobox = nil)
    # source uses "ItemPropertiesWeapon" — strip the prefix; wiki infobox wins
    base = wiki_infobox.to_s.camelize
    base = properties_type.to_s.sub(/\AItemProperties/, "") if base.blank?
    (TYPE_MAP[base] || "Item::Generic").constantize
  end

  def data=(value)
    if value.is_a?(String)
      begin
        super(JSON.parse(value))
      rescue JSON::ParserError
        @data_json_invalid = true
        errors.add(:data, "must be valid JSON")
        super({})
      end
    else
      super(value)
    end
  end

  def stats_partial
    "items/#{self.class.name.demodulize.underscore}_stats"
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
    where(id: OfferUnlock.select(:item_id))
      .or(where(id: BarterUnlock.select(:item_id)))
      .or(where(id: CraftUnlock.select(:item_id)))
  }

  def self.ransackable_attributes(auth_object = nil)
    %w[full_name short_name slug categories type]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[item_barters item_currencies item_hideouts item_task_rewards]
  end

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
