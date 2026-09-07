class Admin::ItemsController < Admin::ApplicationController
  include AdminCrud
  crud_actions model: Item

  private

  def resource_params
    raw = params.require(:item).permit(:bsg_id, :slug, :full_name, :short_name)

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
