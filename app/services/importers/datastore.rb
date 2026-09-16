# frozen_string_literal: true

module Importers
  # Loads `datastore/canonical/` — the verified, cross-checked dataset — into
  # the app schema, replacing every item and task row.
  #
  # Supersedes Importers::Index / TarkovDev / Wiki / TaskGraph: canonical is
  # the same lineage (offlinedata + tarkov.dev localizations), merged,
  # name-resolved and verified (`datastore/reports/04_verification.md`).
  # Field mapping: `datastore/docs/04_db_mapping.md`.
  #
  # Idempotent: truncates the data tables first, so `db:seed` replaces rather
  # than merges into whatever was there.
  class Datastore
    SOURCE = Rails.root.join("datastore/canonical")

    # TRUNCATE ... CASCADE on this set leaves schema_migrations and
    # ar_internal_metadata alone, and resets ids so a reseed is reproducible.
    DATA_TABLES = %w[
      favorite_items
      barter_requirement_items barter_requirements barter_result_items
      barter_results barter_unlocks
      craft_requirement_items craft_requirements craft_result_items
      craft_results craft_unlocks
      item_barter_requirements item_barters item_currencies
      item_hideout_requirements item_hideouts item_task_rewards
      leads_tos loose_items offer_unlocks previous_tasks requirements rewards
      items tasks
    ].freeze

    # Keys the wiki importer kept from the parsed infobox. Canonical keeps that
    # infobox verbatim, so the same slice still applies.
    INFOBOX_KEYS = %w[
      type slot trader node ID caliber def_ammo ammo penetration armor
      default_plates default_plates_armor_class max_uses ergonomics recoil
      range velocity effect
    ].freeze

    IMAGE_KEYS = %w[icon grid base inspect image512 image8x].freeze

    # The wiki infobox keys the views read off `data` when the API value is
    # absent (e.g. `data["penetration"]` behind `penetration_power`).

    def self.import!(source: SOURCE)
      new(source).import!
    end

    def initialize(source = SOURCE)
      @source = Pathname.new(source)
      @items = read("items")
      @tasks = read("tasks")
      @item_id_by_bsg = {}
      @task_id_by_bsg = {}
      @task_id_by_slug = {}
      @task_slug_by_id = @tasks.to_h { |task| [ task["id"], task["slug"] ] }
    end

    def import!
      truncate!
      import_items
      import_tasks
      import_task_graph
      import_item_acquisition
      self
    end

    private

    def read(name)
      @source.join("#{name}.ndjson").each_line.map { |line| JSON.parse(line) }
    end

    def truncate!
      ActiveRecord::Base.connection.execute(
        "TRUNCATE TABLE #{DATA_TABLES.join(', ')} RESTART IDENTITY CASCADE"
      )
    end

    # --- items -----------------------------------------------------------

    def import_items
      Item.transaction do
        @items.each do |raw|
          @item_id_by_bsg[raw["bsg_id"]] = create_item(raw).id
        end
      end
    end

    def create_item(raw)
      infobox = raw.dig("wiki", "infobox") || {}
      Item.new(
        bsg_id:      raw["bsg_id"],
        slug:        raw["slug"],
        full_name:   raw["name"],
        short_name:  raw["short_name"],
        wiki_title:  raw.dig("wiki", "title"),
        type:        Item.type_for(raw["properties_type"]).name,
        categories:  item_categories(raw),
        links:       [ raw.dig("links", "wiki"), raw.dig("links", "tarkovdev"),
                       raw.dig("links", "market") ].compact,
        images:      IMAGE_KEYS.filter_map { |key| raw.dig("images", key) },
        data:        item_data(raw, infobox)
      ).tap(&:save!)
    end

    # `properties` is verbatim tarkov.dev (camelCase). The index importer wrote
    # snake_case names for the same keys and the views read both spellings
    # (`data["penetration_power"] || data["penetration"]`), so keep both.
    #
    # The wiki infobox goes underneath: it is the fallback for what the API
    # does not carry (`penetration`, `armor`, `def_ammo`, ...), and merging it
    # last would replace the raw `Caliber556x45NATO` with the display string
    # the app's caliber filtering and CALIBER_MAP key on.
    def item_data(raw, infobox)
      props = raw["properties"].is_a?(Hash) ? raw["properties"] : {}
      snake = props.to_h { |key, value| [ key.to_s.underscore, value ] }
      infobox.slice(*INFOBOX_KEYS).merge(props).merge(snake).merge(
        "types"         => raw["types"],
        "containsItems" => Array(raw["contains_items"]).map { |c| { "item" => c["bsg_id"], "count" => c["count"] } },
        "mods"          => raw.dig("wiki", "mod_slots"),
        "weapon_variants" => raw.dig("wiki", "weapon_variants")
      ).compact
    end

    # The category filter matches ammo packs by category, not by
    # `data->>'caliber'` (ItemsController#caliber_options), so the item's
    # caliber is carried as a category in the same slug shape as the rest.
    def item_categories(raw)
      leaves = Array(raw.dig("categories", "leaves")) +
               Array(raw.dig("handbook_categories", "leaves"))
      categories = leaves.map { |leaf| leaf.tr("-", "_") }
      caliber = raw.dig("properties", "caliber")
      categories << Item.caliber_display(caliber).downcase.tr(" ", "_") if caliber.present?
      categories.uniq
    end

    # --- tasks -----------------------------------------------------------

    def import_tasks
      Task.transaction do
        @tasks.each do |raw|
          task = Task.find_or_initialize_by(bsg_id: raw["id"])
          task.assign_attributes(
            full_name:            raw["name"],
            name:                 raw["slug"],
            wiki_link:            raw["wiki_link"],
            given_by:             raw["trader_slug"],
            map_id:               raw["map_id"],
            map_name:             raw["map_name"],
            kappa_required:       raw["kappa_required"],
            lightkeeper_required: raw["lightkeeper_required"]
          )
          task.save!
          @task_id_by_bsg[raw["id"]] = task.id
          @task_id_by_slug[raw["slug"]] = task.id
        end
      end
    end

    def import_task_graph
      Task.transaction do
        @tasks.each { |raw| populate_task(raw) }
      end
    end

    def populate_task(raw)
      task = Task.find(@task_id_by_bsg[raw["id"]])
      # Per-task destroy → recreate, so a reseed does not accumulate children.
      task.leads_tos.destroy_all
      task.requirements.destroy_all
      task.rewards.destroy_all

      Array(raw["leads_to"]).each do |entry|
        # `task_id` is blank for most canonical leads_to rows; the follow-up
        # is named by slug, which is the key the Task rows are named by.
        task.leads_tos.create!(
          follow_up_task_id:   @task_id_by_bsg[entry["task_id"]] ||
                               @task_id_by_slug[entry["task_name"]],
          follow_up_task_name: task_slug(entry["task_id"], entry["task_name"])
        )
      end

      import_requirements(task, raw)
      import_rewards(task, raw["start_rewards"], "start_rewards")
      import_rewards(task, raw["finish_rewards"], "finish_rewards")
    end

    # Canonical splits prerequisites across `task_requirements` (the full
    # prerequisite set, 241 edges) and `previous_tasks` (46, the strict
    # previous-only subset) — `Task#prerequisite_chain` wants their union.
    # Both spell their entries inconsistently (`{bsg_id, name}` or a bare id
    # string), and `previous_tasks.task_name` must be the predecessor's *slug*:
    # that is the key `Task#prerequisite_chain` walks the graph by.
    def import_requirements(task, raw)
      previous_tasks = (Array(raw["task_requirements"]) + Array(raw["previous_tasks"]))
                       .map { |entry| entry.is_a?(Hash) ? entry["bsg_id"] : entry }
                       .compact.uniq
      trader_levels = Array(raw["trader_requirements"]).map do |req|
        { "trader_name" => req["trader_slug"], "trader_level" => req["value"].to_s }
      end

      # previous_tasks_count is a counter cache on PreviousTask — assigning it
      # here would be double-counted on top of the cache's own increment.
      requirement = task.requirements.create!(
        player_level: raw["min_player_level"].to_i,
        trader_level: trader_levels
      )

      previous_tasks.each do |bsg_id|
        requirement.previous_tasks.create!(
          task_id:   @task_id_by_bsg[bsg_id],
          task_name: task_slug(bsg_id, nil)
        )
      end
    end

    def import_rewards(task, rewards, reward_type)
      return unless rewards.is_a?(Hash)

      reward = task.rewards.create!(reward_type: reward_type)

      Array(rewards["items"]).each do |entry|
        reward.loose_items.create!(
          item_id:   @item_id_by_bsg[entry["bsg_id"]],
          item_name: entry["name"],
          count:     entry["count"].to_i
        )
      end

      Array(rewards["offer_unlock"]).each do |entry|
        reward.offer_unlocks.create!(
          item_id:      @item_id_by_bsg[entry["bsg_id"]],
          item_name:    entry["name"],
          trader_name:  entry["trader_slug"].to_s.titleize,
          trader_level: entry["level"].to_s
        )
      end

      Array(rewards["barter_unlock"]).each { |entry| import_barter_unlock(reward, entry) }
      Array(rewards["craft_unlock"]).each { |entry| import_craft_unlock(reward, entry) }
    end

    def import_barter_unlock(reward, raw)
      offered = raw["offered"] || {}
      unlock = reward.barter_unlocks.create!(
        item_id:   @item_id_by_bsg[offered["bsg_id"]],
        item_name: offered["name"]
      )

      requirement = unlock.barter_requirements.create!(
        trader_name:  raw["trader_slug"].to_s.titleize,
        trader_level: raw["min_trader_level"].to_s
      )
      Array(raw["required"]).each do |entry|
        requirement.barter_requirement_items.create!(
          item_id:   @item_id_by_bsg[entry["bsg_id"]],
          item_name: entry["name"],
          count:     entry["count"].to_i
        )
      end

      result = unlock.barter_results.create!
      result.barter_result_items.create!(
        item_id:   @item_id_by_bsg[offered["bsg_id"]],
        item_name: offered["name"]
      )
    end

    def import_craft_unlock(reward, raw)
      reward.craft_unlocks.create!(
        item_id:         @item_id_by_bsg[raw["bsg_id"]],
        item_name:       raw["name"],
        hideout_station: raw["station_name"],
        station_level:   raw["level"].to_i
      )
    end

    # --- item acquisition ------------------------------------------------

    def import_item_acquisition
      Item.transaction do
        @items.each do |raw|
          item = Item.find(@item_id_by_bsg[raw["bsg_id"]])
          acquisition = raw["acquisition"] || {}

          # `buy` is tarkov.dev's priced purchase; `index_offers` is the
          # derived index's trader/loyalty claim. They describe the same
          # offers, and only `buy` knows the task gate or the price, so key
          # on (trader, currency, level) and let `buy` win. `task_id` is nil
          # when the route is gated but canonical carried no task, or when
          # only the index knows the offer.
          currencies = {}
          Array(acquisition["buy"]).each do |entry|
            key = currency_key(entry["trader_slug"], entry["currency"], entry["min_trader_level"])
            currencies[key] = {
              task_unlock: entry["task_unlock_id"].present?,
              task_id:     @task_id_by_bsg[entry["task_unlock_id"]],
              price:       entry["price"],
              price_rub:   entry["price_rub"],
              buy_limit:   entry["buy_limit"]
            }
          end
          Array(acquisition["index_offers"]).each do |entry|
            key = currency_key(entry["trader_slug"], entry["currency"], entry["level"])
            currencies[key] ||= { task_unlock: false, task_id: nil,
                                  price: nil, price_rub: nil, buy_limit: nil }
          end
          currencies.each do |(trader, currency, level), attrs|
            item.item_currencies.create!(
              trader: trader, currency: currency, min_trader_level: level, **attrs
            )
          end

          Array(acquisition["barter"]).each do |entry|
            barter = item.item_barters.create!(
              barter_id:      entry["barter_id"],
              trader:         entry["trader_slug"].to_s.titleize,
              trader_level:   entry["min_trader_level"].to_s,
              item_name:      entry.dig("offered", "name"),
              count:          (entry.dig("offered", "count") || 1).to_i,
              buy_limit:      entry["buy_limit"],
              restock_amount: entry["restock_amount"],
              task_id:        @task_id_by_bsg[entry["task_unlock_id"]]
            )
            Array(entry["required"]).each do |req|
              barter.item_barter_requirements.create!(
                item_id:   @item_id_by_bsg[req["bsg_id"]],
                item_name: req["name"],
                count:     req["count"].to_i
              )
            end
          end

          Array(acquisition["craft"]).each do |entry|
            craft = item.item_hideouts.create!(
              craft_id: entry["craft_id"],
              station:  entry["station_name"],
              level:    entry["level"].to_i,
              count:    (entry.dig("product", "count") || 1).to_i,
              duration: entry["duration"],
              task_id:  @task_id_by_bsg[entry["task_unlock_id"]]
            )
            Array(entry["required"]).each do |req|
              craft.item_hideout_requirements.create!(
                item_id:   @item_id_by_bsg[req["bsg_id"]],
                item_name: req["name"],
                count:     req["count"].to_i,
                is_tool:   req["is_tool"] || false
              )
            end
          end

          Array(acquisition["task_rewards"]).each do |entry|
            item.item_task_rewards.create!(
              task_id:   @task_id_by_bsg[entry["task_id"]],
              task_name: entry["task_name"]
            )
          end
        end
      end
    end

    def task_slug(task_id, fallback)
      @task_slug_by_id[task_id].presence || fallback
    end

    def currency_key(trader_slug, currency, level)
      [ trader_slug.to_s.titleize, currency, level.to_i ]
    end
  end
end
