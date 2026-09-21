class ItemsController < ApplicationController
  PER_PAGE = 20
  MAX_PER_PAGE = 100

  # The association graph the show page renders. Preloaded after the freshness
  # check: a 304 skips the view, and Bullet flags every preload the skipped
  # view never touched as an unused eager load.
  SHOW_PRELOADS = [
    :item_currencies,
    { item_task_rewards: :task },
    { item_hideouts: [ :item_hideout_requirements, :task ] },
    { item_barters: [ :item_barter_requirements, :task ] },
    { offer_unlocks: { reward: :task } },
    { barter_unlocks: { reward: :task } },
    { craft_unlocks: { reward: :task } },
    { item_barter_requirements: { item_barter: [ :item, :task ] } },
    { item_hideout_requirements: { item_hideout: [ :item, :task ] } },
    { task_objective_items: { task_objective: :task } }
  ].freeze

  def index
    # Filter dropdowns only change on seed/import: cache the whole block so
    # the ~15 aggregate queries (full-table plucks, per-caliber counts) run
    # once per hour instead of on every index request. Fetched first so
    # apply_filters can reuse its values instead of re-plucking the tables.
    @filter_options = Rails.cache.fetch("items/filter_options/v3", expires_in: 1.hour) do
      {
        currency: currency_options,
        trader: trader_options,
        category: category_options,
        armor_class: armor_class_options,
        caliber: caliber_options,
        source: source_options
      }
    end

    items = Item.all.order(full_name: :asc)
    items = loose_search_param(items, %w[full_name short_name])
    filters = filter_params
    items = apply_filters(items, filters) if filters.present?
    @item_count = items.count

    @current_page = [ int_param(:page), 1 ].max
    @per_page = int_param(:per_page).clamp(PER_PAGE, MAX_PER_PAGE)
    @items = items.offset((@current_page - 1) * @per_page).limit(@per_page)
    @total_pages = (@item_count.to_f / @per_page).ceil
  end

  # Typeahead for the search field.
  def search
    autocomplete(Item.all, columns: %w[full_name short_name],
                            partial: "items/autocomplete_results", local: :items)
  end

  def show
    # Deliberately not `fresh_when`: this page renders the favorites toggle (a
    # form with a session-bound CSRF token) and the toggle's state varies per
    # request, but the cache key would be the item alone. Caching it publicly
    # served a stale "Add favorite" after the item was favorited and let a
    # shared cache hand one visitor's token to another.
    @item = Item.find(params[:id])

    # Unlock associations carry reward → task so the view renders the
    # "How to Unlock" section and raid timelines with zero extra queries.
    ActiveRecord::Associations::Preloader.new(records: [ @item ], associations: SHOW_PRELOADS).call

    # Mod graph: plain queries turned into hashes, so nothing is eager-loaded
    # for the items that have no slots (Bullet reads that as a wasted query).
    slot_rows = @item.item_slots.order(:position).pluck(:id, :name, :required)
    allowed = ItemSlotAllowedItem.where(item_slot_id: slot_rows.map(&:first))
                                 .joins(:item)
                                 .pluck(:item_slot_id, "items.id", "items.full_name")
    @item_slots = slot_rows.map do |slot_id, name, required|
      matches = allowed.select { |row| row[0] == slot_id }
      { name: name, required: required, allowed: matches.map { |row| row.drop(1) } }
    end
    @item_fits = ItemSlotAllowedItem.where(item_id: @item.id)
                                    .joins(item_slot: :item)
                                    .pluck("item_slots.name", "items.id", "items.full_name")
    # Tasks that need this item as a key (needed_keys is jsonb on tasks).
    @item_key_tasks = Task.where("needed_keys @> ?::jsonb", [ { "item_id" => @item.id } ].to_json)
                          .order(:full_name)
                          .to_a
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

  # params[:filters] arrives from the query string, so it can be a String or an
  # Array rather than a nested hash ("?filters=string" 500'd on String#permit).
  # Anything unexpected is read as "no filters".
  def filter_params
    raw = params[:filters]
    raw = ActionController::Parameters.new unless raw.is_a?(ActionController::Parameters)
    raw.permit(
      { currency: [] }, { trader: [] }, { category: [] }, { armor_class: [] },
      { caliber: [] }, { task_required: [] }, { source: [] },
      { exclude_ref: [] }
    )
  end

  # Every filter is independent and applied in turn. Each one skips itself
  # when its whole group is selected, so "all checked" reads as "no filter".
  # The caller reads params once and passes the permitted filters in.
  def apply_filters(items, filters)
    items = filter_exclude_ref(items, filters)
    items = filter_currency(items, filters)
    items = filter_trader(items, filters)
    items = filter_category(items, filters)
    items = filter_armor_class(items, filters)
    items = filter_caliber(items, filters)
    items = filter_task_required(items, filters)
    filter_source(items, filters)
  end

  # Values ticked for one filter group, ignoring blank entries.
  def selected_values(filters, key)
    Array(filters[key]).reject(&:blank?)
  end

  # A group that is fully selected is a no-op, so its filter is skipped.
  def partial_selection?(values, total)
    values.any? && values.size < total
  end

  # Items whose categories array overlaps any of the given category names.
  #
  # The elements are bound individually (`ARRAY[?]`) rather than joined into a
  # Postgres array literal by hand: a filter value containing a quote, brace or
  # comma made the literal invalid, and `?filters[category][]=x"y` answered 500
  # with a PG array-literal error.
  def categories_overlap(scope, categories)
    scope.where("categories && ARRAY[?]::text[]", categories)
  end

  def filter_exclude_ref(items, filters)
    return items unless selected_values(filters, :exclude_ref).include?("1")

    items.where.not(id: ItemCurrency.where(trader: "Ref").select(:item_id))
  end

  def filter_currency(items, filters)
    currencies = selected_values(filters, :currency)
    return items unless partial_selection?(currencies, @filter_options[:currency].size)

    items.joins(:item_currencies).where(item_currencies: { currency: currencies }).distinct
  end

  # Category expands pack/box/bundle variants of each selected base.
  # "What can I buy from Therapist?" — the Source filter only says "some trader".
  def filter_trader(items, filters)
    traders = selected_values(filters, :trader)
    return items unless partial_selection?(traders, @filter_options[:trader].size)

    items.joins(:item_currencies).where(item_currencies: { trader: traders }).distinct
  end

  def filter_category(items, filters)
    categories = selected_values(filters, :category)
    return items unless partial_selection?(categories, @filter_options[:category].size)

    all_cats = Item.category_list
    expanded = categories.flat_map do |cat|
      [ cat ] + all_cats.select { |c| c.start_with?("#{cat}_") && c != cat }
    end
    categories_overlap(items, expanded)
  end

  def filter_armor_class(items, filters)
    armor_classes = selected_values(filters, :armor_class)
    return items unless partial_selection?(armor_classes, @filter_options[:armor_class].size)

    items.where("data->>'class' IN (?)", armor_classes)
  end

  # Matches data->>'caliber' OR a caliber category (ammo packs, ammo boxes).
  # Subselects keep the id lists in Postgres instead of materializing
  # thousands of ids into Ruby for a giant IN (...) list.
  def filter_caliber(items, filters)
    calibers = selected_values(filters, :caliber)
    return items unless partial_selection?(calibers, @filter_options[:caliber].size)

    caliber_ids = Item.where("data->>'caliber' IN (?)", calibers).select(:id)
    cats = calibers.flat_map { |c| caliber_map[c] || [] }.uniq
    return items.where(id: caliber_ids) if cats.empty?

    category_ids = categories_overlap(Item, cats).select(:id)
    items.where(id: caliber_ids).or(items.where(id: category_ids))
  end

  def filter_task_required(items, filters)
    return items unless selected_values(filters, :task_required).include?("1")

    items.task_gated
  end

  SOURCE_VALUES = %w[barter craft trader hideout task_gated].freeze
  SOURCE_ASSOCIATIONS = {
    "barter" => :item_barters,
    "craft" => :item_task_rewards,
    "trader" => :item_currencies,
    "hideout" => :item_hideouts
  }.freeze

  def filter_source(items, filters)
    sources = selected_values(filters, :source)
    return items unless partial_selection?(sources, SOURCE_VALUES.size)

    scope = Item.none
    SOURCE_ASSOCIATIONS.each do |key, association|
      scope = scope.or(items.joins(association).distinct) if sources.include?(key)
    end
    scope = scope.or(items.task_gated) if sources.include?("task_gated")
    scope
  end

  def currency_options
    @currency_options ||= ItemCurrency.group(:currency).count.sort_by { |c, _| c }.map do |c, count|
      { value: c, label: c, count: count }
    end
  end

  def trader_options
    @trader_options ||= begin
      counts = ItemCurrency.group(:trader).distinct.count(:item_id)
      counts.sort_by { |trader, _| trader.to_s }.map do |trader, count|
        { value: trader, label: trader.to_s.titleize, count: count }
      end
    end
  end

  def category_options
    @category_options ||= begin
      grouped = grouped_categories
      variant_counts = variant_counts_for(grouped.values.flatten)

      grouped.sort_by { |base, _| base }.map do |base, variants|
        { value: base, label: helpers.category_label(base), count: variants.sum { |v| variant_counts[v] } }
      end
    end
  end

  # Base category → its pack/box/bundle variants. Drops caliber-like bases
  # (they belong to the caliber filter now).
  def grouped_categories
    grouped = {}
    Item.category_list.each do |c|
      base = c.sub(/_(pack|box|bundle)\z/, "")
      (grouped[base] ||= []) << c
    end
    caliber_bases = caliber_map_bases
    grouped.reject { |base, _| caliber_bases.include?(base) }
  end

  # One grouped query for all variant counts instead of one per category.
  def variant_counts_for(variants)
    counts = variants.each_with_object(Hash.new(0)) { |v, h| h[v] = 0 }
    return counts if variants.empty?

    categories_overlap(Item, variants)
        .group(Arel.sql("unnest(categories)")).count
        .each { |cat, count| counts[cat] = count if counts.key?(cat) }
    counts
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
    @caliber_options ||= Item.distinct.pluck(Arel.sql("data->>'caliber'")).compact.sort.map do |c|
      { value: c, label: Item.caliber_display(c), count: caliber_option_count(c) }
    end
  end

  # Union of data-matched and category-matched items (deduplicated by id).
  def caliber_option_count(caliber)
    cats = caliber_map[caliber] || []
    scope = Item.where("data->>'caliber' = ?", caliber)
    scope = scope.or(categories_overlap(Item, cats)) if cats.any?
    scope.count
  end

  SOURCE_LABELS = {
    "barter" => "Barter",
    # The value stays "craft" so existing filtered URLs keep working, but the
    # data behind it is quest rewards — the item page calls this "Quest".
    "craft" => "Quest reward",
    "trader" => "Trader",
    "hideout" => "Hideout"
  }.freeze

  def source_options
    @source_options ||= SOURCE_ASSOCIATIONS.map do |value, association|
      { value: value, label: SOURCE_LABELS[value], count: Item.joins(association).distinct.count }
    end + [ { value: "task_gated", label: "Task Required", count: Item.task_gated.count } ]
  end
end
