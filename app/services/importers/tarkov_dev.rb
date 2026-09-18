# frozen_string_literal: true

module Importers
  class TarkovDev
    SOURCE = Rails.root.join("offlinedata/tarkovdev/items.json")
    TRADERS_SOURCE = Rails.root.join("offlinedata/tarkovdev/traders.json")

    WEAPON_PROPS = %w[caliber allowedAmmo slots presets defaultPreset].freeze
    AMMO_PROPS = %w[caliber stackMaxSize tracer tracerColor ammoType damage penetrationPower].freeze
    ARMOR_PROPS = %w[class].freeze
    COMMON_PROPS = %w[types categories containsItems].freeze

    # Properties to keep per BSG propertiesType (the "ItemProperties" prefix is
    # stripped before lookup).
    TYPE_PROPS = {
      "Weapon" => WEAPON_PROPS,
      "Ammo" => AMMO_PROPS,
      "Armor" => ARMOR_PROPS
    }.freeze

    def self.import!(source: SOURCE, traders_source: TRADERS_SOURCE)
      new(source, traders_source).import!
    end

    def initialize(source, traders_source = TRADERS_SOURCE)
      @source = source
      @traders_source = traders_source
      @trader_names = load_trader_names
    end

    def import!
      items = document.dig("data", "items") || document
      items.each do |bsg_id, raw|
        item = Item.find_by(bsg_id: bsg_id)
        next unless item
        import_item(item, raw)
      end
    end

    private

    # Parsed once and reused: the import used to read the file here and again in
    # item_categories, re-parsing the whole multi-megabyte document for items
    # whose categories needed resolving.
    def document
      @document ||= JSON.parse(File.read(@source))
    end

    def load_trader_names
      data = JSON.parse(File.read(@traders_source))
      data.dig("data") || {}
    end

    def trader_name(trader_id)
      trader = @trader_names[trader_id]
      trader ? trader["normalizedName"].capitalize : trader_id
    end

    def import_item(item, raw)
      links = [ raw["wikiLink"], raw["link"] ].compact
      item.links = links if links.any?
      item.images = [ raw["iconLink"], raw["gridImageLink"], raw["baseImageLink"],
                     raw["inspectImageLink"], raw["image512pxLink"], raw["image8xLink"] ].compact
      item.data = item.data.merge(kept_properties(raw))
      # Preset items come from the index with only ["preset"]; resolve their
      # BSG category IDs into real categories (armor, equipment, ...).
      categories = item.categories
      item.categories |= resolved_categories(raw) if categories.include?("preset")
      item.save!
      import_buy_from_trader(item, raw["buyFromTrader"] || [])
    end

    def resolved_categories(raw)
      Array(raw["categories"]).filter_map { |id| item_categories[id] }
        .map { |c| c["normalizedName"].tr("-", "_") }.uniq - [ "item" ]
    end

    def item_categories
      document.dig("data", "itemCategories") || {}
    end

    def kept_properties(raw)
      props = {}
      COMMON_PROPS.each do |k|
        value = raw[k]
        props[k] = value if value
      end

      properties_type = raw.dig("properties", "propertiesType").to_s.sub(/\AItemProperties/, "")
      Array(TYPE_PROPS[properties_type]).each do |k|
        value = raw.dig("properties", k)
        props[k] = value if value
      end
      props
    end

    def import_buy_from_trader(item, entries)
      entries.each do |entry|
        item.item_currencies.find_or_create_by!(
          trader: trader_name(entry["trader"]),
          currency: entry["currency"],
          min_trader_level: entry["minTraderLevel"],
          task_unlock: entry["taskUnlock"] || false
        )
      end
    end
  end
end
