class Admin::PropertiesController < Admin::ApplicationController
  include AdminCrud
  crud_actions model: Property

  private

  def resource_params
    params.require(:property).permit(
      :item_id, :properties_type, :allowed_ammo, :ammo_type, :armor_slots,
      :armor_type, :base_item, :caliber, :armor_class, :damage, :default,
      :default_ammo, :default_preset, :penetration_power, :presets,
      :slash_damage, :stab_damage, :category, :zones,
      allowed_ammo: [], armor_slots: [], presets: [], zones: []
    )
  end
end
