# frozen_string_literal: true

module Importers
  # Imports the full task graph from `offlinedata/tarkovunlockables/tasks_index.json`.
  #
  # Order requirements: items must already exist in `items` (bsg_id is the join key)
  # before this importer runs — see `db/seeds.rb`.
  #
  # Idempotency: per-task destroy + recreate of leads_tos / requirements / rewards
  # (which cascade through their children). Tasks themselves are upserted by bsg_id.
  class TaskGraph
    SOURCE = Rails.root.join("offlinedata/tarkovunlockables/tasks_index.json")

    def self.import!(source: SOURCE)
      new(source).import!
    end

    def initialize(source)
      @source = source
    end

    def import!
      # Pass 1: upsert every Task row so FKs (leads_tos.follow_up_task_id,
      # previous_tasks.task_id) can resolve on pass 2 regardless of JSON order.
      tasks_data.each { |raw| upsert_task(raw) }

      # Pass 2: graph + rewards + requirements.
      tasks_data.each { |raw| populate_task(raw) }
    end

    private

    def tasks_data
      @tasks_data ||= JSON.parse(File.read(@source))
    end

    def upsert_task(raw)
      task = Task.find_or_initialize_by(bsg_id: raw["bsg_id"])
      task.assign_attributes(
        full_name:            raw["full_name"],
        name:                 raw["name"],
        wiki_link:            raw["wiki_link"],
        given_by:             raw["given_by"],
        kappa_required:       raw["kappa_required"],
        lightkeeper_required: raw["lightkeeper_required"]
      )
      task.save!
    end

    def populate_task(raw)
      task = Task.find_by!(bsg_id: raw["bsg_id"])

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
        task.leads_tos.create!(
          follow_up_task_id:   Task.find_by(bsg_id: lt["task_id"])&.id,
          follow_up_task_name: lt["task_name"]
        )
      end
    end

    def import_requirements(task, requirements)
      requirements.each do |req|
        requirement = task.requirements.create!(
          player_level: req["player_level"].to_i,
          trader_level: req["trader_level"] || []
        )
        previous_tasks = req["previous_tasks"] || []
        previous_tasks.each do |pt|
          requirement.previous_tasks.create!(
            task_id:   Task.find_by(bsg_id: pt["task_id"])&.id,
            task_name: pt["task_name"]
          )
        end
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
        result_items  = bu.dig("result", 0, "items") || []
        first_item    = result_items.first || {}
        barter_unlock = reward.barter_unlocks.create!(
          item_id:   item_id_for(first_item["item_id"]),
          item_name: first_item["item_name"]
        )

        (bu["requirements"] || []).each do |req|
          barter_req = barter_unlock.barter_requirements.create!(
            trader_name:  req["trader_name"].to_s.capitalize,
            trader_level: strip_ll(req["trader_level"])
          )

          (req["items"] || []).each do |ri|
            barter_req.barter_requirement_items.create!(
              item_id:   item_id_for(ri["item_id"]),
              item_name: ri["item_name"],
              count:     ri["count"].to_i
            )
          end
        end

        (bu["result"] || []).each do |res|
          barter_result = barter_unlock.barter_results.create!
          (res["items"] || []).each do |ri|
            barter_result.barter_result_items.create!(
              item_id:   item_id_for(ri["item_id"]),
              item_name: ri["item_name"]
            )
          end
        end
      end
    end

    def import_craft_unlocks(reward, craft_unlocks)
      craft_unlocks.each do |cu|
        result_items    = cu.dig("result", 0, "items") || []
        first_result    = result_items.first || {}
        item_id         = cu["item_id"].presence || first_result["id"]
        item_name       = cu["item_name"].presence || first_result["name"]
        craft_unlock    = reward.craft_unlocks.create!(
          item_id:         item_id_for(item_id),
          item_name:       item_name,
          hideout_station: cu["hideout_station"],
          station_level:   cu["station_level"].to_i
        )

        (cu["requirements"] || []).each do |req|
          craft_req = craft_unlock.craft_requirements.create!(
            trader_name:  req["trader_name"].to_s.capitalize,
            trader_level: strip_ll(req["trader_level"])
          )

          (req["items"] || []).each do |ri|
            craft_req.craft_requirement_items.create!(
              item_id:   item_id_for(ri["id"]),
              item_name: ri["name"],
              count:     ri["quantity"].to_i
            )
          end
        end

        (cu["result"] || []).each do |res|
          craft_result = craft_unlock.craft_results.create!
          (res["items"] || []).each do |ri|
            craft_result.craft_result_items.create!(
              item_id:   item_id_for(ri["id"]),
              item_name: ri["name"]
            )
          end
        end
      end
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
