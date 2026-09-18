class TasksController < ApplicationController
  def index
    tasks = Task.all
    tasks = loose_search_param(tasks, %w[full_name name])
    tasks = tasks.where(given_by: params[:trader]) if params[:trader].present?
    tasks = tasks.where(map_name: params[:map]) if params[:map].present?
    # Players chase the Kappa set specifically.
    tasks = tasks.where(kappa_required: true) if params[:kappa].present?
    @tasks = tasks.order(full_name: :asc)
    @task_count = tasks.count
    @traders = cached_traders
    @kappa_count = cached_kappa_count
    @maps = cached_maps
    # How many keys each task asks for, for the row chips (one query).
    @key_counts = Task.where("jsonb_array_length(needed_keys) > 0")
                      .pluck(:id, Arel.sql("jsonb_array_length(needed_keys)"))
                      .to_h
  end

  # Typeahead for the quest search field.
  def search
    autocomplete(Task.all, columns: %w[full_name name],
                            partial: "tasks/autocomplete_results", local: :tasks)
  end

  # The association graph the show page renders. Preloaded *after* the freshness
  # check: a 304 skips the view, and Bullet raises on every preload the skipped
  # view never touched (which 500s cached-page revalidation in development) while
  # production pays for a graph nobody reads.
  SHOW_PRELOADS = [
    { requirements: { previous_tasks: :task } },
    { rewards: [
      { loose_items: :item },
      { offer_unlocks: :item },
      { barter_unlocks: :item },
      { craft_unlocks: :item }
    ] },
    { leads_tos: :follow_up_task },
    { gated_currencies: :item }
  ].freeze

  def show
    @task = Task.find(params[:id])
    fresh_when(@task, public: true)
    return if performed?

    ActiveRecord::Associations::Preloader.new(records: [ @task ], associations: SHOW_PRELOADS).call
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

  # Trader list and Kappa count only change on import, so cache them instead
  # of running DISTINCT/count on every request.
  def cached_traders
    Rails.cache.fetch("tasks/traders", expires_in: 1.hour) do
      Task.distinct.pluck(:given_by).compact.sort
    end
  end

  def cached_maps
    Rails.cache.fetch("tasks/maps", expires_in: 1.hour) do
      Task.where.not(map_name: [ nil, "" ]).distinct.order(:map_name).pluck(:map_name)
    end
  end

  def cached_kappa_count
    Rails.cache.fetch("tasks/kappa_count", expires_in: 1.hour) do
      Task.where(kappa_required: true).count
    end
  end

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
