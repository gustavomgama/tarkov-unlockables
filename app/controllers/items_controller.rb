class ItemsController < ApplicationController
  PER_PAGE = 20

  def index
    @item_count = Item.count

    items = Item.all.order(full_name: :asc)
    items = apply_filters(items) if params[:filters].present?

    page = params[:page].to_i
    page = 1 if page < 1
    @items = items.offset((page - 1) * PER_PAGE).limit(PER_PAGE)
    @current_page = page
    @total_pages = (@item_count.to_f / PER_PAGE).ceil

    @filter_options = {
      currency: currency_options,
      category: category_options,
      armor_class: armor_class_options,
      caliber: caliber_options,
      source: source_options
    }
  end

  def show
    @item = Item.find(params[:id])
  end

  private

  def apply_filters(items)
    filters = params[:filters].permit(:currency, { category: [] }, :armor_class, :caliber, :task_required)

    if filters[:currency].present?
      items = items.joins(:item_currencies)
        .where(item_currencies: { currency: filters[:currency] })
        .distinct
    end

    if filters[:category].present?
      categories = filters[:category]
      # Build PostgreSQL array string like '{headphones,mod}' or single '{headphones}'
      pg_array = categories.length == 1 ? "{#{categories[0]}}" : "{#{categories.join(',')}}"
      items = items.where("categories && ?", pg_array)
    end

    if filters[:armor_class].present?
      items = items.where("data->>'class' = ?", filters[:armor_class])
    end

    if filters[:caliber].present?
      items = items.where("data->>'caliber' = ?", filters[:caliber])
    end

    if filters[:task_required].present? && filters[:task_required] == "1"
      items = items.task_gated
    end

    items
  end

  def currency_options
    currencies = ItemCurrency.distinct.pluck(:currency).compact.sort
    currencies.map { |c| { value: c, label: c, count: ItemCurrency.where(currency: c).count } }
  end

  def category_options
    categories = Item.pluck(:categories).flatten.uniq.sort
    categories.map do |c|
      count = Item.where("categories && ?", [ "{#{c}}" ]).count
      { value: c, label: c.humanize, count: count }
    end
  end

  def armor_class_options
    armor_classes = Item.distinct.pluck(Arel.sql("data->>'class'")).compact.sort
    armor_classes.map do |ac|
      count = Item.where("data->>'class' = ?", ac).count
      { value: ac, label: "Class #{ac}", count: count }
    end
  end

  def caliber_options
    calibers = Item.distinct.pluck(Arel.sql("data->>'caliber'")).compact.sort
    calibers.map do |c|
      count = Item.where("data->>'caliber' = ?", c).count
      { value: c, label: c.gsub("Caliber", "").humanize, count: count }
    end
  end

  def source_options
    [
      { value: "barter", label: "Barter", count: Item.joins(:item_barters).distinct.count },
      { value: "craft", label: "Craft", count: Item.joins(:item_task_rewards).distinct.count },
      { value: "trader", label: "Trader", count: Item.joins(:item_currencies).distinct.count },
      { value: "hideout", label: "Hideout", count: Item.joins(:item_hideouts).distinct.count },
      { value: "task_gated", label: "Task Required", count: Item.task_gated.count }
    ]
  end
end
