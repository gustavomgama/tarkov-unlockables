# frozen_string_literal: true

module Items
  # Collapses base-only weapon rows into their default preset.
  #
  # Some guns only exist in-game as pre-configured presets (tarkov.dev still
  # exports the bare base weapon row). For those, the Default preset row
  # becomes the canonical item: it inherits the base row's weapon data
  # (ergonomics, recoil, mods...), is promoted to Item::Weapon, absorbs the
  # base row's obtain references, and the base row is deleted.
  #
  # Scoped by an explicit allowlist — most base weapons with presets (M4A1,
  # AS VAL, ...) are legitimately trader-bought and must stay.
  #
  # Idempotent: skipped when the base row is absent (already collapsed).
  # Run after Importers::TarkovDev in db/seeds.rb so re-imports re-collapse.
  class CollapseBaseWeapons
    # User-curated: base weapons that only exist in-game as their preset.
    BASE_WEAPON_IDS = [
      3256, # ADAR 2-15
      3258, # AS VAL
      3259, # ASh-12.7
      3260, # Accuracy International AXMC
      3261, # Aklys Defense Velociraptor
      3263, # Beretta M9A3
      3264, # Benelli M3 Super 90
      3266, # CMMG Mk47 Mutant
      3267, # Chiappa Rhino 200DS
      3268, # Chiappa Rhino 50DS
      3271, # Colt M1911A1
      3272, # Colt M45A1
      3273, # Colt M16A2
      3274  # Colt M16A1
    ].freeze

    # Keys the preset owns — the base row's values must not overwrite them.
    PRESET_IDENTITY_KEYS = %w[base_item default types caliber categories containsItems].freeze

    class << self
      def call(ids = BASE_WEAPON_IDS)
        Item::Weapon.where(id: ids).find_each { |base| collapse(base) }
      end

      private

      def collapse(base)
        preset = default_preset_for(base)
        return unless preset

        preset.update!(
          data: preset.data.merge(base.data.except(*PRESET_IDENTITY_KEYS)),
          type: "Item::Weapon"
        )
        retarget(preset, base)
        base.destroy!
      end

      def default_preset_for(base)
        Item::Generic.where("data->>'base_item' = ?", base.bsg_id)
          .where("data->>'default' = 'true'")
          .first
      end

      def retarget(preset, base)
        base.offer_unlocks.update_all(item_id: preset.id) # rubocop:disable Rails/SkipsModelValidations
        base.loose_items.update_all(item_id: preset.id) # rubocop:disable Rails/SkipsModelValidations
        merge_currencies(preset, base)
      end

      def merge_currencies(preset, base)
        base.item_currencies.find_each do |currency|
          preset.item_currencies.find_or_create_by!(
            trader: currency.trader,
            currency: currency.currency,
            min_trader_level: currency.min_trader_level,
            task_unlock: currency.task_unlock
          )
        end
      end
    end
  end
end
