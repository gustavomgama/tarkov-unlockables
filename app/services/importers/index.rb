# frozen_string_literal: true

module Importers
  class Index
    SOURCE = Rails.root.join("offlinedata/tarkovunlockables/items_index.json")

    # snake_case keys actually present in items_index.json properties
    KEPT_PROPERTIES = %w[
      caliber allowed_ammo default_ammo default_preset presets slots
      ammo_type damage penetration_power class armor_type armor_slots zones
      slash_damage stab_damage base_item default type
    ].freeze

    def self.import!(source: SOURCE)
      new(source).import!
    end

    def initialize(source)
      @source = source
    end

    def import!
      data = JSON.parse(File.read(@source))
      data.each { |raw| import_item(raw) }
    end

    private

    def import_item(raw)
      return if raw["bsg_id"].blank?

      item = Item.find_or_initialize_by(bsg_id: raw["bsg_id"])
      props = raw["properties"]
      properties_type = props.is_a?(Hash) ? props["properties_type"] : nil
      item.type = Item.type_for(properties_type).name
      item.slug = raw["slug"]
      item.full_name = raw["full_name"]
      item.short_name = raw["short_name"]
      item.categories = raw["categories"] || []
      item.data = kept_properties(raw["properties"] || {})
      item.save!
      import_obtain_from(item, raw["obtain_from"] || [])
    end

    def kept_properties(props)
      props.is_a?(Hash) ? props.slice(*KEPT_PROPERTIES) : {}
    end

    def import_obtain_from(item, entries)
      item.item_currencies.destroy_all
      item.item_task_rewards.destroy_all
      item.item_hideouts.destroy_all
      item.item_barters.destroy_all

      entries.each do |entry|
        (entry["task_rewards"] || []).each do |tr|
          item.item_task_rewards.create!(task_name: tr["task_name"])
        end
        (entry["hideout"] || []).each do |h|
          item.item_hideouts.create!(station: h["station_name"], level: h["station_level"])
        end
        (entry["barter"] || []).each do |b|
          item.item_barters.create!(trader: b["trader_name"].to_s.capitalize, trader_level: b["trader_level"].to_s.gsub(/LL/i, ""))
        end
        (entry["currency"] || []).each do |c|
          item.item_currencies.create!(
            trader: c["trader_name"].to_s.capitalize,
            currency: c["currency"],
            min_trader_level: c["trader_level"].to_s.gsub(/LL/i, "").to_i
          )
        end
      end
    end
  end
end
