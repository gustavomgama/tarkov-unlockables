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
  # Scope: every base weapon referenced as base_item by a default:true
  # preset — the trader-sold, in-game obtainable version. Every such base
  # duplicates its Default preset in listings; the preset row is the real
  # item (trader offers point at the configured weapon).
  #
  # Idempotent: skipped when the base row is absent (already collapsed).
  # Run after Importers::TarkovDev in db/seeds.rb so re-imports re-collapse.
  class CollapseBaseWeapons
    # Keys the preset owns — the base row's values must not overwrite them.
    PRESET_IDENTITY_KEYS = %w[base_item default types caliber categories containsItems].freeze

    class << self
      def call(ids = nil)
        scope = ids ? Item::Weapon.where(id: ids) : Item::Weapon.where(bsg_id: default_preset_base_bsgs)
        scope.find_each { |base| collapse(base) }
      end

      private

      def default_preset_base_bsgs
        Item::Generic.where("data->>'base_item' IS NOT NULL")
          .where("data->>'default' = 'true'")
          .pluck(Arel.sql("data->>'base_item'")).uniq
      end

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
        base.barter_unlocks.update_all(item_id: preset.id) # rubocop:disable Rails/SkipsModelValidations
        base.barter_result_items.update_all(item_id: preset.id) # rubocop:disable Rails/SkipsModelValidations
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
