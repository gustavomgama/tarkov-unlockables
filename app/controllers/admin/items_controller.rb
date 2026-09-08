class Admin::ItemsController < Admin::ApplicationController
  include AdminCrud
  crud_actions model: Item
  searchable_columns :full_name, :short_name

  private

  def resource_params
    raw = params.require(:item).permit(
      :type, :bsg_id, :slug, :full_name, :short_name, :wiki_title, :data,
      :categories, :links, :images,
      item_currencies_attributes: %i[id trader currency min_trader_level task_unlock _destroy],
      item_task_rewards_attributes: %i[id task_id task_name _destroy],
      item_hideouts_attributes: %i[id station level _destroy],
      item_barters_attributes: %i[id trader trader_level currency cost item_name _destroy]
    )

    raw[:categories] = normalize_to_array(params[:item][:categories], ",")
    raw[:links] = normalize_to_array(params[:item][:links], "\n")
    raw[:images] = normalize_to_array(params[:item][:images], "\n")

    raw
  end

  def normalize_to_array(value, delimiter)
    return [] if value.blank?
    if value.is_a?(Array)
      value.flat_map { |v| v.to_s.split(delimiter) }.map(&:strip).reject(&:blank?)
    else
      value.to_s.split(delimiter).map(&:strip).reject(&:blank?)
    end
  end
end
