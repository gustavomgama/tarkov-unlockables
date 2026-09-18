class TasksController < ApplicationController
  def index
    tasks = Task.all
    tasks = tasks.loose_search(params[:q], columns: %w[full_name name]) if params[:q].present?
    tasks = tasks.where(given_by: params[:trader]) if params[:trader].present?
    tasks = tasks.where(map_name: params[:map]) if params[:map].present?
    # Players chase the Kappa set specifically.
    tasks = tasks.where(kappa_required: true) if params[:kappa].present?
    @tasks = tasks.order(full_name: :asc)
    @task_count = tasks.count
    # Trader list only changes on import: cache instead of DISTINCT on every request.
    @traders = Rails.cache.fetch("tasks/traders", expires_in: 1.hour) do
      Task.distinct.pluck(:given_by).compact.sort
    end
    @maps = Rails.cache.fetch("tasks/maps", expires_in: 1.hour) do
      Task.where.not(map_name: [ nil, "" ]).distinct.order(:map_name).pluck(:map_name)
    end
    # How many keys each task asks for, for the row chips (one query).
    @key_counts = Task.where("jsonb_array_length(needed_keys) > 0")
                      .pluck(:id, Arel.sql("jsonb_array_length(needed_keys)"))
                      .to_h
    @kappa_count = Rails.cache.fetch("tasks/kappa_count", expires_in: 1.hour) do
      Task.where(kappa_required: true).count
    end
  end

  # Typeahead for the quest search field. Mirrors ItemsController#search.
  def search
    query = params[:q].to_s.strip
    return head :no_content if query.length < ItemsController::AUTOCOMPLETE_MIN_QUERY

    @tasks = Task.all
                 .loose_search(query, columns: %w[full_name name])
                 .order(full_name: :asc)
                 .limit(ItemsController::AUTOCOMPLETE_LIMIT)
    return head :no_content if @tasks.empty?

    expires_in 10.minutes, public: true
    render partial: "tasks/autocomplete_results", locals: { tasks: @tasks }, layout: false
  end

  def show
    @task = Task.includes(
      requirements: { previous_tasks: :task },
      rewards: [
        { loose_items: :item },
        { offer_unlocks: :item },
        { barter_unlocks: :item },
        { craft_unlocks: :item }
      ],
      leads_tos: :follow_up_task,
      gated_currencies: :item
    ).find(params[:id])
    fresh_when(@task, public: true)
  end

  def chains
    @tasks = Task.includes(requirements: :previous_tasks).order(full_name: :asc)
    fresh_when(etag: [ @tasks.maximum(:updated_at), @tasks.count ], public: true)
    # Deepest-chain walk is pure Ruby over the preloaded graph (~500ms);
    # the graph only changes on import, so cache it hourly.
    @trader_chains = Rails.cache.fetch("tasks/chains", expires_in: 1.hour) do
      build_trader_chains(@tasks)
    end
  end

  private

  def build_trader_chains(tasks)
    map = tasks.index_by(&:name)
    tasks.group_by(&:given_by).sort_by { |trader, _| trader.to_s }.filter_map do |trader, trader_tasks|
      next if trader.blank?
      deepest, chain = trader_tasks.to_h { |t| [ t, t.prerequisite_chain([], map) ] }
                                   .max_by { |_, c| c.length }
      next if deepest.nil? || chain.length < 2
      [ trader, deepest, chain ]
    end
  end
end
