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
  # barter/craft unlocks are not leaves: their requirements/results (and those
  # rows' items) point back at them, so `delete_all` would bypass BarterUnlock's
  # own dependent: :destroy and leave orphaned rows the restrict FK then rejects
  # — deleting any item that has a barter or craft unlock raised a foreign-key
  # violation instead of destroying it.
  has_many :barter_unlocks, dependent: :destroy
  has_many :craft_unlocks, dependent: :destroy
  has_many :barter_requirement_items, dependent: :delete_all
  has_many :barter_result_items, dependent: :delete_all
  has_many :craft_requirement_items, dependent: :delete_all
  has_many :craft_result_items, dependent: :delete_all
  # The FK is `on_delete: :restrict`, so without this an item anyone favorited
  # cannot be destroyed at all — the admin delete action 500s on a foreign-key
  # violation, and re-imports that drop items fail the same way.
  has_many :favorite_items, dependent: :delete_all

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
      caliber = caliber_from_item(item)
      next if caliber.blank?

      item.update_column(:data, (item.data || {}).merge("caliber" => caliber))
    end
  end

  def self.caliber_from_item(item)
    parse_caliber_from_name(item.full_name) ||
      parse_caliber_from_name(item.slug) ||
      parse_caliber_from_name(item.wiki_title)
  end

  # Maps caliber display name → matching categories, including the
  # _pack/_box/_bundle variants so an ammo pack matches its caliber too.
  # Computed on demand (not at class load) so boot never touches the DB and
  # re-imported data is reflected immediately.
  def self.caliber_category_map
    cached("caliber_category_map") { build_caliber_category_map }
  end

  # Full category list backing filter expansion. Cached: changes only on import.
  def self.category_list
    cached("category_list") { pluck(:categories).flatten.uniq }
  end

  # Item lookups that only change on import share one cache namespace and TTL.
  def self.cached(key, &block)
    Rails.cache.fetch("items/#{key}", expires_in: 1.hour, &block)
  end

  def self.build_caliber_category_map
    cal_cats = category_list.select { |c| c.sub(/_(pack|box|bundle)\z/, "").match?(/^\d|^\./) }

    raw_calibers = Item.distinct.pluck(Arel.sql("data->>'caliber'")).compact
    display_to_cats = {}
    raw_calibers.each do |raw|
      display = Item.caliber_display(raw)
      next if display.start_with?("Caliber")
      next if display_to_cats.key?(display)

      display_to_cats[display] = matching_categories(display, cal_cats)
    end
    display_to_cats
  end

  # Categories whose normalized name equals, extends, or is extended by the
  # caliber's normalized name ("5.45x39mm" → "545x39_pack").
  def self.matching_categories(display, cal_cats)
    normalized = normalize_caliber(display)
    cal_cats.select do |category|
      base = normalize_caliber(category.sub(/_(pack|box|bundle)\z/, ""))
      base == normalized || base.start_with?(normalized) || normalized.start_with?(base)
    end
  end

  # Normalize: lowercase, strip non-alphanumeric, strip 'x', strip trailing 'mm'
  def self.normalize_caliber(value)
    value.downcase.gsub(/[^a-zA-Z0-9]/, "").gsub("x", "").sub(/mm\z/, "")
  end

  # Links come from the wiki import and are rendered as an `href`. A stored
  # `javascript:`/`data:` value is not a link, it is stored XSS, so the
  # template asks for these instead of the raw column.
  def external_links
    Array(links).select { |url| url.to_s.match?(%r{\Ahttps?://}i) }
  end

  def ammo_packs
    return Item.none unless bsg_id.present?
    Item.where(type: "Item::Generic")
        .where("data->'containsItems' @> ?", [ { "item" => bsg_id } ].to_json)
  end

  # Guarded casts for the comparison ordering. A plain ::int raises on any
  # non-integer value the import might store ("31.5", "n/a"), which would
  # take the whole caliber listing down with it.
  PEN_ORDER = "CASE WHEN data->>'penetration_power' ~ '^[0-9]+$' " \
              "THEN (data->>'penetration_power')::int END DESC NULLS LAST".freeze
  DMG_ORDER = "CASE WHEN data->>'damage' ~ '^[0-9]+$' " \
              "THEN (data->>'damage')::int END DESC NULLS LAST".freeze

  # The round's own caliber, hardest-hitting first. A penetration number only
  # means something next to its siblings, so the ammo page leads with this
  # comparison and the table highlights this round in it (`current:` in
  # _ammo_table) — excluding self here left that highlight unreachable.
  def caliber_ammo(limit: 14)
    raw = data["caliber"]
    return Item.none if raw.blank?

    Item::Ammo.where("data->>'caliber' = ?", raw)
              .order(Arel.sql(PEN_ORDER), Arel.sql(DMG_ORDER))
              .limit(limit)
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

  def requires_task?
    %w[OfferUnlock BarterUnlock CraftUnlock].any? do |model_name|
      model_name.constantize.exists?(item_id: id)
    end || item_currencies.where(task_unlock: true).exists?
  end

  # An item is task-gated through any unlock row, or through a trader offer that
  # a quest unlocks. Without the last clause an item gated only via its trader
  # offer slips the "Task Required" filter (101 offers in the source carry a
  # taskUnlock).
  scope :task_gated, -> {
    where(id: OfferUnlock.select(:item_id))
      .or(where(id: BarterUnlock.select(:item_id)))
      .or(where(id: CraftUnlock.select(:item_id)))
      .or(where(id: ItemCurrency.where(task_unlock: true).select(:item_id)))
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
end
