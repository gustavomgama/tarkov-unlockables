class Admin::ItemsController < Admin::ApplicationController
  include AdminCrud
  crud_actions model: Item
  searchable_columns :full_name, :short_name

  private

  def resource_params
    raw = params.require(:item).permit(
      :type, :bsg_id, :slug, :full_name, :short_name, :wiki_title, :data,
      # The empty-array entries are what permit an array of values; the plain
      # symbols keep a single comma/newline-delimited string working too.
      :categories, :links, :images,
      categories: [], links: [], images: [],
      item_currencies_attributes: %i[id trader currency min_trader_level task_unlock _destroy],
      item_task_rewards_attributes: %i[id task_id task_name _destroy],
      item_hideouts_attributes: %i[id station level _destroy],
      item_barters_attributes: %i[id trader trader_level currency cost item_name _destroy]
    )

    raw[:categories] = split_list(raw[:categories], ",")
    raw[:links] = split_list(raw[:links], "\n")
    raw[:images] = split_list(raw[:images], "\n")

    # `type` is a raw param behind a select of Item.descendants. An unknown value
    # (a crafted POST, or a form left open across a class rename) reaches STI
    # instantiation and raises ActiveRecord::SubclassNotFound — a 500. Drop it so
    # the column default applies on create and the existing value is kept on
    # update.
    raw.delete(:type) unless item_subclass?(raw[:type])

    raw
  end

  def item_subclass?(value)
    klass = value.presence&.safe_constantize
    klass.present? && klass < Item
  end

  # A scalar or an array of delimited strings, flattened to trimmed values.
  def split_list(value, delimiter)
    Array(value).flat_map { |entry| entry.to_s.split(delimiter) }.map(&:strip).reject(&:blank?)
  end
end
