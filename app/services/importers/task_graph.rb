# frozen_string_literal: true

module Importers
  # Imports the full task graph from `offlinedata/tarkovunlockables/tasks_index.json`.
  #
  # Order requirements: items must already exist in `items` (bsg_id is the join key)
  # before this importer runs — see `db/seeds.rb`.
  #
  # Idempotency: per-task destroy + recreate of leads_tos / requirements / rewards
  # (which cascade through their children). Tasks themselves are upserted by bsg_id.
  class TaskGraph < JsonImport
    SOURCE = Rails.root.join("offlinedata/tarkovunlockables/tasks_index.json")

    def import!
      # Pass 1: upsert every Task row so FKs (leads_tos.follow_up_task_id,
      # previous_tasks.task_id) can resolve on pass 2 regardless of JSON order.
      records.each { |raw| upsert_task(raw) }

      # Pass 2: graph + rewards + requirements.
      records.each { |raw| populate_task(raw) }
    end

    private

    def upsert_task(raw)
      task = find_or_new_task(raw)
      task.assign_attributes(
        full_name:            raw["full_name"],
        name:                 task_name_for(raw),
        wiki_link:            raw["wiki_link"],
        given_by:             raw["given_by"],
        kappa_required:       raw["kappa_required"],
        lightkeeper_required: raw["lightkeeper_required"]
      )
      task.save!
    end

    # 52 Ref/Arena quests carry no bsg_id in the source (and no name slug).
    # Keying on the blank bsg_id collapsed all of them into one row — 51 quests
    # were lost — and the duplicate blank names then collided in the chain map,
    # which indexes tasks by name. `full_name` is unique across the source, so it
    # is the fallback identity. Both lookups share it.
    def task_identity(raw)
      bsg_id = raw["bsg_id"]
      return { bsg_id: bsg_id } if bsg_id.present?

      { bsg_id: nil, full_name: raw["full_name"] }
    end

    def find_or_new_task(raw)
      Task.find_or_initialize_by(task_identity(raw))
    end

    def find_task!(raw)
      Task.find_by!(task_identity(raw))
    end

    # Those same quests have no slug; derive one from the full name (measured
    # unique against every name in the source and against the existing slugs).
    def task_name_for(raw)
      raw["name"].presence || raw["full_name"].to_s.parameterize
    end

    def populate_task(raw)
      task = find_task!(raw)

      # Per-task destroy → recreate. has_many dependent: :destroy fires
      # child destroy callbacks in turn (loose_items, barter_unlocks, etc.).
      task.leads_tos.destroy_all
      task.requirements.destroy_all
      task.rewards.destroy_all

      import_leads_tos(task, raw["leads_to"] || [])
      import_requirements(task, raw["requirements"] || [])
      import_rewards(task, raw["start_rewards"] || [], "start_rewards")
      import_rewards(task, raw["finish_rewards"] || [], "finish_rewards")
    end

    def import_leads_tos(task, leads_to)
      leads_to.each do |lt|
        create_task_link(task.leads_tos, lt, id_attr: :follow_up_task_id, name_attr: :follow_up_task_name)
      end
    end

    def import_requirements(task, requirements)
      requirements.each do |req|
        requirement = task.requirements.create!(
          player_level: req["player_level"].to_i,
          trader_level: req["trader_level"] || []
        )
        (req["previous_tasks"] || []).each do |pt|
          create_task_link(requirement.previous_tasks, pt, id_attr: :task_id, name_attr: :task_name)
        end
      end
    end

    # Links a row to another task by bsg_id. The referenced task may not be
    # imported yet, in which case the id stays nil and only the name is kept.
    def create_task_link(association, raw, id_attr:, name_attr:)
      linked_id = linked_task_id(raw)
      name = raw["task_name"].presence
      # A reference with neither a resolved link nor a name carries nothing:
      # the source has 48 such `leads_to` rows, and the page would render an
      # empty chip / count a lead that names no quest.
      return if linked_id.nil? && name.nil?

      association.create!(id_attr => linked_id, name_attr => name)
    end

    # 502 references leave task_id blank (408 of them name the task's slug
    # instead), so resolve by slug when the id is missing — looking up
    # `bsg_id: ""` used to hand back whichever blank-id row happened to exist.
    def linked_task_id(raw)
      task_id = raw["task_id"]
      if task_id.present?
        Task.find_by(bsg_id: task_id)&.id
      else
        Task.find_by(name: raw["task_name"])&.id
      end
    end

    def import_rewards(task, rewards, reward_type)
      rewards.each do |reward_data|
        next if reward_data.nil?

        reward = task.rewards.create!(reward_type: reward_type)

        import_loose_items(reward, reward_data["loose_items"] || [])
        import_offer_unlocks(reward, reward_data["offer_unlocks"] || [])
        import_barter_unlocks(reward, reward_data["barter_unlocks"] || [])
        import_craft_unlocks(reward, reward_data["craft_unlocks"] || [])
      end
    end

    def import_loose_items(reward, loose_items)
      loose_items.each do |li|
        reward.loose_items.create!(
          item_id:   item_id_for(li["item_id"]),
          item_name: li["item_name"],
          count:     li["count"].to_i
        )
      end
    end

    def import_offer_unlocks(reward, offer_unlocks)
      offer_unlocks.each do |ou|
        reward.offer_unlocks.create!(
          item_id:      item_id_for(ou["item_id"]),
          item_name:    ou["item_name"],
          trader_name:  ou["trader_name"].to_s.capitalize,
          trader_level: strip_ll(ou["trader_level"])
        )
      end
    end

    def import_barter_unlocks(reward, barter_unlocks)
      barter_unlocks.each do |bu|
        first_item    = first_result_item(bu)
        barter_unlock = reward.barter_unlocks.create!(
          item_id:   item_id_for(first_item["item_id"]),
          item_name: first_item["item_name"]
        )

        # Barter JSON uses item_id/item_name/count keys.
        import_requirement_tree(barter_unlock, :barter_requirements, :barter_requirement_items,
                                bu["requirements"], id_key: "item_id", name_key: "item_name", count_key: "count")
        import_result_tree(barter_unlock, :barter_results, :barter_result_items,
                           bu["result"], id_key: "item_id", name_key: "item_name")
      end
    end

    def import_craft_unlocks(reward, craft_unlocks)
      craft_unlocks.each do |cu|
        first_result    = first_result_item(cu)
        item_id         = cu["item_id"].presence || first_result["id"]
        item_name       = cu["item_name"].presence || first_result["name"]
        craft_unlock    = reward.craft_unlocks.create!(
          item_id:         item_id_for(item_id),
          item_name:       item_name,
          hideout_station: cu["hideout_station"],
          station_level:   cu["station_level"].to_i
        )

        # Craft JSON uses id/name/quantity keys for the same shapes.
        import_requirement_tree(craft_unlock, :craft_requirements, :craft_requirement_items,
                                cu["requirements"], id_key: "id", name_key: "name", count_key: "quantity")
        import_result_tree(craft_unlock, :craft_results, :craft_result_items,
                           cu["result"], id_key: "id", name_key: "name")
      end
    end

    # Barter and craft share the same nesting: a trader-gated requirement row
    # owning item rows. id_key/name_key/count_key map each source's JSON keys.
    def import_requirement_tree(unlock, requirement_assoc, item_assoc, requirements, id_key:, name_key:, count_key:)
      (requirements || []).each do |req|
        requirement = unlock.public_send(requirement_assoc).create!(
          trader_name:  req["trader_name"].to_s.capitalize,
          trader_level: strip_ll(req["trader_level"])
        )

        import_item_rows(requirement, item_assoc, req["items"], id_key: id_key, name_key: name_key, count_key: count_key)
      end
    end

    # Result rows own item rows with no trader gate and no count.
    def import_result_tree(unlock, result_assoc, item_assoc, results, id_key:, name_key:)
      (results || []).each do |res|
        result = unlock.public_send(result_assoc).create!

        import_item_rows(result, item_assoc, res["items"], id_key: id_key, name_key: name_key)
      end
    end

    # Item rows hang off either a requirement or a result row. count_key is
    # nil for result items, which carry no count.
    def import_item_rows(owner, item_assoc, items, id_key:, name_key:, count_key: nil)
      (items || []).each do |ri|
        attrs = { item_id: item_id_for(ri[id_key]), item_name: ri[name_key] }
        attrs[:count] = ri[count_key].to_i if count_key
        owner.public_send(item_assoc).create!(attrs)
      end
    end

    # First entry of a reward's `result` array, or {} when absent.
    def first_result_item(raw)
      (raw.dig("result", 0, "items") || []).first || {}
    end

    def item_id_for(bsg_id)
      return nil if bsg_id.blank?
      Item.find_by(bsg_id: bsg_id)&.id
    end

    def strip_ll(raw)
      raw.to_s.gsub(/LL/i, "")
    end
  end
end
