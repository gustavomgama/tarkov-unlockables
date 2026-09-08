# frozen_string_literal: true

module Importers
  class TarkovDev
    SOURCE = Rails.root.join("offlinedata/tarkovdev/items.json")
    TRADERS_SOURCE = Rails.root.join("offlinedata/tarkovdev/traders.json")

    WEAPON_PROPS = %w[caliber allowedAmmo slots presets defaultPreset].freeze
    AMMO_PROPS = %w[caliber stackMaxSize tracer tracerColor ammoType damage penetrationPower].freeze
    ARMOR_PROPS = %w[class].freeze
    COMMON_PROPS = %w[types categories containsItems].freeze

    def self.import!(source: SOURCE, traders_source: TRADERS_SOURCE)
      new(source, traders_source).import!
    end

    def initialize(source, traders_source = TRADERS_SOURCE)
      @source = source
      @traders_source = traders_source
      @trader_names = load_trader_names
    end

    def import!
      data = JSON.parse(File.read(@source))
      items = data.dig("data", "items") || data
      items.each do |bsg_id, raw|
        item = Item.find_by(bsg_id: bsg_id)
        next unless item
        import_item(item, raw)
      end
    end

    private

    def load_trader_names
      data = JSON.parse(File.read(@traders_source))
      data.dig("data") || {}
    end

    def trader_name(trader_id)
      trader = @trader_names[trader_id]
      trader ? trader["normalizedName"].capitalize : trader_id
    end

    def import_item(item, raw)
      item.links = [ raw["wikiLink"], raw["link"] ].compact if raw["wikiLink"] || raw["link"]
      item.images = [ raw["iconLink"], raw["gridImageLink"], raw["baseImageLink"],
                     raw["inspectImageLink"], raw["image512pxLink"], raw["image8xLink"] ].compact
      item.data = item.data.merge(kept_properties(raw))
      item.save!
      import_buy_from_trader(item, raw["buyFromTrader"] || [])
    end

    def kept_properties(raw)
      props = {}
      COMMON_PROPS.each { |k| props[k] = raw[k] if raw[k] }

      properties_type = raw.dig("properties", "propertiesType").to_s.sub(/\AItemProperties/, "")
      case properties_type
      when "Weapon"
        WEAPON_PROPS.each { |k| props[k] = raw.dig("properties", k) if raw.dig("properties", k) }
      when "Ammo"
        AMMO_PROPS.each { |k| props[k] = raw.dig("properties", k) if raw.dig("properties", k) }
      when "Armor"
        ARMOR_PROPS.each { |k| props[k] = raw.dig("properties", k) if raw.dig("properties", k) }
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
