class Admin::SlotsController < Admin::ApplicationController
  include AdminCrud
  crud_actions model: Slot

  private

  def resource_params
    params.require(:slot).permit(
      :property_id, :name_id, :required,
      allowed_items: [], allowed_categories: [], excluded_categories: [], excluded_items: []
    )
  end
end
