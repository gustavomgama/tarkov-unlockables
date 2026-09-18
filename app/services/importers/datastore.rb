# frozen_string_literal: true

module Importers
  # Loads `datastore/canonical/` — the verified, cross-checked dataset — into
  # the app schema, replacing every item and task row.
  #
  # An item with no acquisition route is dropped on the way in: nothing that is
  # not bought, bartered, crafted or handed out by a quest gets a page. Recipes
  # and task keys that mention one keep its name, they just lose the link.
  #
  # Supersedes the offlinedata-derived importers (index, tarkov.dev, wiki and
  # task graph): canonical is the same lineage, merged, name-resolved and
  # verified (`datastore/reports/04_verification.md`).
  # Field mapping: `datastore/docs/04_db_mapping.md`.
  #
  # Idempotent: truncates the data tables first, so `db:seed` replaces rather
  # than merges into whatever was there.
  class Datastore
    SOURCE = Rails.root.join("datastore/canonical")

    # The acquisition branches that make an item worth a page.
    OBTAINABLE_KINDS = %w[buy index_offers barter craft task_rewards].freeze

    # The reward buckets `import_rewards` is called with, and the ones that
    # unlock a route for the item they name.
    REWARD_KINDS = %w[start_rewards finish_rewards].freeze
    UNLOCK_KINDS = %w[offer_unlock barter_unlock craft_unlock].freeze

    # TRUNCATE ... CASCADE on this set leaves schema_migrations and
    # ar_internal_metadata alone, and resets ids so a reseed is reproducible.
    DATA_TABLES = %w[
      favorite_items
      barter_requirement_items barter_requirements barter_result_items
      barter_results barter_unlocks
      craft_requirement_items craft_requirements craft_result_items
      craft_results craft_unlocks
      hideout_item_requirements hideout_levels hideout_stations
      maps
      item_barter_requirements item_barters item_currencies
      item_hideout_requirements item_hideouts
      item_slot_allowed_items item_slots
      leads_tos loose_items offer_unlocks previous_tasks requirements rewards
      task_objective_items task_objectives item_task_rewards
      trader_levels traders
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
      @hideout_stations = read("hideout_stations")
      @traders = read("traders")
      @maps = read("maps")
      @item_id_by_bsg = {}
      @task_id_by_bsg = {}
      @task_id_by_slug = {}
      @task_slug_by_id = @tasks.to_h { |task| [ task["id"], task["slug"] ] }
      @item_name_by_bsg = @items.to_h { |item| [ item["bsg_id"], item["name"] ] }
      @unlocked_item_bsg = unlocked_item_bsg
    end

    # One transaction around everything: Postgres TRUNCATE is transactional, so
    # readers keep the old rows until commit and a failure rolls the whole load
    # back instead of leaving the reference tables truncated.
    def import!
      ActiveRecord::Base.transaction do
        truncate!
        import_items
        import_slots
        import_tasks
        import_task_graph
        import_item_acquisition
        import_hideout
        import_traders
        import_maps
      end
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
          next unless obtainable?(raw)

          @item_id_by_bsg[raw["bsg_id"]] = create_item(raw).id
        end
      end
    end

    # A drop-only item (no trader offer, barter, hideout craft or quest reward)
    # has nothing to show, so it never reaches the database.
    def obtainable?(raw)
      return true if @unlocked_item_bsg.include?(raw["bsg_id"])

      acquisition = raw["acquisition"]
      acquisition.is_a?(Hash) && OBTAINABLE_KINDS.any? { |kind| Array(acquisition[kind]).any? }
    end

    # Items a quest unlocks at a trader, as a barter or as a craft. A few of
    # them (the SCAR-L, the HK USP, the D-60 magazine) are missing that route
    # on the item record itself, so the task reward is the only proof they are
    # obtainable — dropping them would lose a weapon the quest hands you.
    def unlocked_item_bsg
      @tasks.flat_map do |task|
        REWARD_KINDS.flat_map do |kind|
          rewards = task[kind]
          next [] unless rewards.is_a?(Hash)

          UNLOCK_KINDS.flat_map do |unlock|
            Array(rewards[unlock]).filter_map do |entry|
              entry["bsg_id"] || entry.dig("offered", "bsg_id")
            end
          end
        end
      end.to_set
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
      # `physical` is the only home for weight, grid size and stack size; the
      # item page reads them straight off `data`.
      physical = raw["physical"].is_a?(Hash) ? raw["physical"] : {}
      infobox.slice(*INFOBOX_KEYS).merge(props).merge(snake).merge(physical).merge(
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

    # --- mod graph -------------------------------------------------------

    # 3,564 slots and 39,910 allowed-item edges in one pass. insert_all keeps
    # it seconds instead of a minute of individual inserts, so the slot ids
    # are re-read once to map (item, slot bsg id) -> row id.
    def import_slots
      now = Time.current
      slot_rows = []
      allowed = []

      @items.each do |raw|
        parent_id = @item_id_by_bsg[raw["bsg_id"]]
        next unless parent_id

        Array(raw["slots"]).each_with_index do |slot, index|
          slot_rows << {
            item_id: parent_id, slot_id: slot["id"], name_id: slot["name_id"],
            name: slot["name"], required: slot["required"] || false,
            position: index, created_at: now, updated_at: now
          }
          Array(slot.dig("filters", "allowed_items")).each do |allowed_bsg|
            allowed << [ [ parent_id, slot["id"] ], allowed_bsg ]
          end
        end
      end

      ItemSlot.insert_all(slot_rows) if slot_rows.any?
      slot_ids = ItemSlot.pluck(:item_id, :slot_id, :id)
                         .to_h { |item_id, slot_id, id| [ [ item_id, slot_id ], id ] }

      edge_rows = allowed.filter_map do |key, allowed_bsg|
        slot_id = slot_ids[key]
        next unless slot_id
        { item_slot_id: slot_id, item_id: @item_id_by_bsg[allowed_bsg],
          created_at: now, updated_at: now }
      end
      edge_rows.each_slice(5_000) { |batch| ItemSlotAllowedItem.insert_all(batch) }
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
            experience:           raw["experience"],
            faction:              raw["faction"],
            needed_keys:          task_needed_keys(raw),
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
      task.task_objectives.destroy_all

      Array(raw["objectives"]).each_with_index do |raw_objective, index|
        objective = task.task_objectives.create!(
          objective_id:   raw_objective["id"],
          objective_type: raw_objective["type"],
          description:    raw_objective["description"],
          count:          raw_objective["count"],
          optional:       raw_objective["optional"] || false,
          position:       index
        )

        items = Array(raw_objective.dig("raw", "items"))
        # Catch-alls ("sell any items to Ragman", 3,500+ ids) describe a
        # category, so the ids add nothing and would swamp reverse usage.
        next if items.size > 100
        items.each do |bsg_id|
          objective.task_objective_items.create!(
            item_id:   @item_id_by_bsg[bsg_id],
            item_name: @item_name_by_bsg[bsg_id] || bsg_id
          )
        end
      end

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
      # Prerequisites the wiki joins with `or`: any one of them suffices.
      alternatives = Array(raw["alternative_previous_tasks"])
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
          task_id:     @task_id_by_bsg[bsg_id],
          task_name:   task_slug(bsg_id, nil),
          alternative: alternatives.include?(bsg_id)
        )
      end
    end

    # The four reward kinds with a table get modelled; the rest (trader
    # standing, skill levels, achievements, customizations, trader and
    # dialogue unlocks) are display-only and ride along as jsonb.
    MODELLED_REWARD_KINDS = %w[items offer_unlock barter_unlock craft_unlock].freeze

    def import_rewards(task, rewards, reward_type)
      return unless rewards.is_a?(Hash)

      reward = task.rewards.create!(
        reward_type: reward_type,
        data: rewards.except(*MODELLED_REWARD_KINDS).each_with_object({}) do |(kind, entries), out|
          out[kind] = entries if Array(entries).any?
        end
      )

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
      # 30 canonical craft unlocks are empty placeholders (every field null);
      # the reward row for one would render as a blank "Craft".
      return if raw["bsg_id"].blank? && raw["name"].blank? && raw["station_name"].blank?

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
          item_id = @item_id_by_bsg[raw["bsg_id"]]
          next unless item_id

          item = Item.find(item_id)
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

    # --- hideout ---------------------------------------------------------

    def import_hideout
      HideoutStation.transaction do
        @hideout_stations.each_with_index do |raw, index|
          station = HideoutStation.create!(
            bsg_id: raw["id"], slug: raw["slug"], name: raw["name"],
            image_url: raw["image_url"], area_type: raw["area_type"], position: index
          )

          Array(raw["levels"]).each do |level_raw|
            level = station.hideout_levels.create!(
              level: level_raw["level"],
              construction_time: level_raw["construction_time"],
              station_requirements: hideout_station_requirements(level_raw),
              trader_requirements: hideout_trader_requirements(level_raw)
            )
            Array(level_raw["item_requirements"]).each do |req|
              level.hideout_item_requirements.create!(
                item_id:       @item_id_by_bsg[req["bsg_id"]],
                item_name:     req["name"],
                count:         req["count"].to_i,
                found_in_raid: req["found_in_raid"] || false
              )
            end
          end
        end
      end
    end

    def hideout_station_requirements(level_raw)
      Array(level_raw["station_level_requirements"]).map do |req|
        { "station_name" => req["station_name"], "level" => req["level"] }
      end
    end

    def hideout_trader_requirements(level_raw)
      Array(level_raw["trader_requirements"]).map do |req|
        { "name" => req["trader_slug"].to_s.titleize, "level" => req["level"] }
      end
    end

    # --- traders ---------------------------------------------------------

    def import_traders
      Trader.transaction do
        @traders.each do |raw|
          trader = Trader.create!(
            bsg_id: raw["id"], slug: raw["slug"], name: raw["name"],
            description: raw["description"], currency: raw["currency"],
            image_url: raw["image_url"], task_count: raw["task_count"]
          )
          Array(raw["levels"]).each do |level_raw|
            trader.trader_levels.create!(
              level:                  level_raw["level"],
              required_player_level:  level_raw["required_player_level"],
              required_reputation:    level_raw["required_reputation"],
              required_commerce:      level_raw["required_commerce"],
              pay_rate:               level_raw["pay_rate"],
              insurance_rate:         level_raw["insurance_rate"],
              repair_cost_multiplier: level_raw["repair_cost_multiplier"]
            )
          end
        end
      end
    end

    # --- maps ------------------------------------------------------------

    def import_maps
      Map.transaction do
        @maps.each do |raw|
          Map.create!(
            bsg_id: raw["id"], slug: raw["slug"], name: raw["name"],
            name_id: raw["name_id"], wiki_link: raw["wiki_link"],
            description: raw["description"], raid_duration: raw["raid_duration"],
            players: raw["players"], enemies: Array(raw["enemies"]),
            bosses: Array(raw["bosses"]), extracts: Array(raw["extracts"]),
            transits: Array(raw["transits"])
          )
        end
      end
    end

    def task_slug(task_id, fallback)
      @task_slug_by_id[task_id].presence || fallback
    end

    # Canonical groups keys by map; flatten so the view can group again for
    # display and link each key to its item.
    def task_needed_keys(raw)
      Array(raw["needed_keys"]).flat_map do |group|
        Array(group["keys"]).map do |key|
          {
            "map_name"  => group["map_name"],
            "item_id"   => @item_id_by_bsg[key["bsg_id"]],
            "item_name" => key["name"]
          }
        end
      end
    end
    def currency_key(trader_slug, currency, level)
      [ trader_slug.to_s.titleize, currency, level.to_i ]
    end
  end
end
