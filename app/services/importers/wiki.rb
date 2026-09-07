# frozen_string_literal: true

module Importers
  class Wiki
    SOURCE = Rails.root.join("offlinedata/officialwiki/parsed_items.json")

    KEPT_INFOBOX = %w[type slot trader node ID caliber def_ammo ammo penetration armor
                      default_plates default_plates_armor_class max_uses ergonomics recoil
                      range velocity effect].freeze

    def self.import!(source: SOURCE)
      new(source).import!
    end

    def initialize(source)
      @source = source
    end

    def import!
      data = JSON.parse(File.read(@source))
      data.each do |bsg_id, parsed|
        item = Item.find_by(bsg_id: bsg_id)
        next unless item
        item.wiki_title = parsed["full_name"]
        item.full_name = parsed["full_name"] if parsed["full_name"].present?
        item.data = item.data.merge(kept_infobox(parsed["infobox"] || {}))
        item.data["mods"] = parsed.dig("sections", "mods") if parsed.dig("sections", "mods").present?
        item.data["weapon_variants"] = parsed.dig("sections", "weapon_variants") if parsed.dig("sections", "weapon_variants").present?
        item.save!
      end
    end

    private

    def kept_infobox(infobox)
      infobox.slice(*KEPT_INFOBOX)
    end
  end
end
