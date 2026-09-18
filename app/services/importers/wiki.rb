# frozen_string_literal: true

module Importers
  class Wiki < JsonImport
    SOURCE = Rails.root.join("offlinedata/officialwiki/parsed_items.json")

    KEPT_INFOBOX = %w[type slot trader node ID caliber def_ammo ammo penetration armor
                      default_plates default_plates_armor_class max_uses ergonomics recoil
                      range velocity effect].freeze

    # Sections carried over into item.data when the wiki parser found them.
    KEPT_SECTIONS = %w[mods weapon_variants].freeze

    def import!
      records.each do |bsg_id, parsed|
        item = Item.find_by(bsg_id: bsg_id)
        next unless item

        assign_wiki_fields(item, parsed)
        item.save!
      end
    end

    private

    def assign_wiki_fields(item, parsed)
      full_name = parsed["full_name"]
      item.wiki_title = full_name
      item.full_name = full_name if full_name.present?
      item.data = item.data.merge(kept_infobox(parsed["infobox"] || {}))
      KEPT_SECTIONS.each { |section| assign_section(item, parsed, section) }
    end

    def assign_section(item, parsed, section)
      value = parsed.dig("sections", section)
      item.data[section] = value if value.present?
    end

    def kept_infobox(infobox)
      infobox.slice(*KEPT_INFOBOX)
    end
  end
end
