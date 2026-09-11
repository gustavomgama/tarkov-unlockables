class ItemsController < ApplicationController
  PER_PAGE = 20
  MAX_PER_PAGE = 100

  def index
    items = Item.all.order(full_name: :asc)
    items = items.loose_search(params[:q], columns: %w[full_name short_name]) if params[:q].present?
    items = apply_filters(items) if params[:filters].present?
    @item_count = items.count

    page = params[:page].to_i
    page = 1 if page < 1
    per_page = [ params[:per_page].to_i, 1 ].max
    per_page = MAX_PER_PAGE if per_page > MAX_PER_PAGE
    per_page = PER_PAGE if per_page < PER_PAGE
    @items = items.offset((page - 1) * per_page).limit(per_page)
    @current_page = page
    @per_page = per_page
    @total_pages = (@item_count.to_f / per_page).ceil

    # Filter dropdowns only change on seed/import: cache the whole block so
    # the ~15 aggregate queries (full-table plucks, per-caliber counts) run
    # once per hour instead of on every index request.
    @filter_options = Rails.cache.fetch("items/filter_options", expires_in: 1.hour) do
      {
        currency: currency_options,
        category: category_options,
        armor_class: armor_class_options,
        caliber: caliber_options,
        source: source_options
      }
    end
  end

  def show
    # Unlock associations carry reward → task so the view renders the
    # "How to Unlock" section and raid timelines with zero extra queries.
    @item = Item.includes(
      :item_task_rewards, :item_hideouts, :item_barters, :item_currencies,
      { item_task_rewards: :task },
      { offer_unlocks: { reward: :task } },
      { barter_unlocks: { reward: :task } },
      { craft_unlocks: { reward: :task } }
    ).find(params[:id])
  end

  private

  # Computed once per request so the caliber/category mapping queries don't
  # repeat across filter and dropdown helpers.
  def caliber_map
    @caliber_map ||= Item.caliber_category_map
  end

  def caliber_map_bases
    caliber_map.values.flatten.uniq
  end

  def apply_filters(items)
    filters = params[:filters].permit(
      { currency: [] }, { category: [] }, { armor_class: [] },
      { caliber: [] }, { task_required: [] }, { source: [] },
      { exclude_ref: [] }
    )

    # Exclude Ref: drop items obtainable from the Ref trader
    if Array(filters[:exclude_ref]).include?("1")
      items = items.where.not(id: ItemCurrency.where(trader: "Ref").select(:item_id))
    end

    # Currency: skip if all selected
    currencies = Array(filters[:currency]).reject(&:blank?)
    all_currencies = ItemCurrency.distinct.pluck(:currency).compact
    if currencies.any? && currencies.size < all_currencies.size
      items = items.joins(:item_currencies)
        .where(item_currencies: { currency: currencies })
        .distinct
    end

    # Category: skip if all selected; expand pack/box/bundle variants
    categories = Array(filters[:category]).reject(&:blank?)
    all_category_bases = category_options.map { |o| o[:value] }
    if categories.any? && categories.size < all_category_bases.size
      all_cats = Item.pluck(:categories).flatten.uniq
      expanded = categories.flat_map do |cat|
        [ cat ] + all_cats.select { |c| c.start_with?("#{cat}_") && c != cat }
      end
      pg_array = "{#{expanded.join(',')}}"
      items = items.where("categories && ?", pg_array)
    end

    # Armor class: skip if all selected
    armor_classes = Array(filters[:armor_class]).reject(&:blank?)
    all_armor_classes = Item.distinct.pluck(Arel.sql("data->>'class'")).compact
    if armor_classes.any? && armor_classes.size < all_armor_classes.size
      items = items.where("data->>'class' IN (?)", armor_classes)
    end

    # Caliber: skip if all selected — matches data field OR caliber categories
    calibers = Array(filters[:caliber]).reject(&:blank?)
    all_calibers = Item.distinct.pluck(Arel.sql("data->>'caliber'")).compact
    if calibers.any? && calibers.size < all_calibers.size
      # Items matching by data->>'caliber'
      caliber_ids = Item.where("data->>'caliber' IN (?)", calibers).pluck(:id)
      # Items matching by caliber category (ammo packs, ammo boxes)
      cats_for_calibers = calibers.flat_map { |c| caliber_map[c] || [] }.uniq
      if cats_for_calibers.any?
        pg_array = "{#{cats_for_calibers.join(',')}}"
        category_ids = Item.where("categories && ?", pg_array).pluck(:id)
        items = items.where(id: caliber_ids | category_ids)
      else
        items = items.where(id: caliber_ids)
      end
    end

    # Task required: only filter if explicitly checked
    task_required = Array(filters[:task_required]).reject(&:blank?)
    if task_required.include?("1")
      items = items.task_gated
    end

    # Source: skip if all selected
    sources = Array(filters[:source]).reject(&:blank?)
    all_source_values = %w[barter craft trader hideout task_gated]
    if sources.any? && sources.size < all_source_values.size
      scope = Item.none
      scope = scope.or(items.joins(:item_barters).distinct) if sources.include?("barter")
      scope = scope.or(items.joins(:item_task_rewards).distinct) if sources.include?("craft")
      scope = scope.or(items.joins(:item_currencies).distinct) if sources.include?("trader")
      scope = scope.or(items.joins(:item_hideouts).distinct) if sources.include?("hideout")
      scope = scope.or(items.task_gated) if sources.include?("task_gated")
      items = scope
    end

    items
  end

  def currency_options
    @currency_options ||= begin
      counts = ItemCurrency.group(:currency).count
      counts.sort_by { |c, _| c }.map do |c, count|
        { value: c, label: c, count: count }
      end
    end
  end

  def category_options
    @category_options ||= begin
      categories = Item.pluck(:categories).flatten.uniq
      grouped = {}
      categories.each do |c|
        base = c.sub(/_(pack|box|bundle)\z/, "")
        grouped[base] ||= []
        grouped[base] << c
      end
      # Exclude caliber-like categories (they're in the caliber filter now)
      caliber_bases = caliber_map_bases
      grouped.reject! { |base, _| caliber_bases.include?(base) }

      # One grouped query for all variant counts instead of one per category
      all_variants = grouped.values.flatten
      variant_counts = all_variants.each_with_object(Hash.new(0)) { |v, h| h[v] = 0 }
      if all_variants.any?
        Item.where("categories && ?", "{#{all_variants.join(',')}}")
            .group(Arel.sql("unnest(categories)")).count
            .each { |cat, count| variant_counts[cat] = count if variant_counts.key?(cat) }
      end

      grouped.sort_by { |base, _| base }.map do |base, variants|
        { value: base, label: base.humanize, count: variants.sum { |v| variant_counts[v] } }
      end
    end
  end

  def armor_class_options
    @armor_class_options ||= begin
      counts = Item.where("data->>'class' IS NOT NULL").group(Arel.sql("data->>'class'")).count
      counts.sort_by { |ac, _| ac }.map do |ac, count|
        { value: ac, label: "Class #{ac}", count: count }
      end
    end
  end

  def caliber_options
    @caliber_options ||= begin
      calibers = Item.distinct.pluck(Arel.sql("data->>'caliber'")).compact.sort
    # One grouped query for data-field counts
    data_counts = Item.where("data->>'caliber' IS NOT NULL")
                      .group(Arel.sql("data->>'caliber'")).count
    # One grouped query for category-based counts (ammo packs/boxes)
    all_cal_cats = caliber_map.values.flatten.uniq
    cat_counts = Hash.new(0)
    if all_cal_cats.any?
      Item.where("categories && ?", "{#{all_cal_cats.join(',')}}")
          .group(Arel.sql("unnest(categories)")).count
          .each { |cat, count| cat_counts[cat] = count }
    end

      calibers.map do |c|
        cats = caliber_map[c] || []
        # Union of data-matched and category-matched items (deduplicated by id)
        count = Item.where("data->>'caliber' = ?", c).or(
          cats.any? ? Item.where("categories && ?", "{#{cats.join(',')}}") : Item.none
        ).count
        { value: c, label: Item.caliber_display(c), count: count }
      end
    end
  end

  def source_options
    @source_options ||= [
      { value: "barter", label: "Barter", count: Item.joins(:item_barters).distinct.count },
      { value: "craft", label: "Craft", count: Item.joins(:item_task_rewards).distinct.count },
      { value: "trader", label: "Trader", count: Item.joins(:item_currencies).distinct.count },
      { value: "hideout", label: "Hideout", count: Item.joins(:item_hideouts).distinct.count },
      { value: "task_gated", label: "Task Required", count: Item.task_gated.count }
    ]
  end
end
