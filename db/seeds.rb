puts "Starting import..."

json_dir = Rails.root.join("offlinedata/tarkovunlockables")

# Helper to convert trader level string to integer
def trader_level_to_int(level)
  return nil if level.blank?
  level.to_s.gsub(/LL/i, "").to_i
end

# ============================================
# Import Items
# ============================================
puts "Importing items..."

items_data = JSON.parse(File.read(json_dir.join("items_index.json")))

items_data.each do |item_data|
  bsg_id = item_data["bsg_id"]

  item = Item.find_or_initialize_by(bsg_id: bsg_id)
  item.assign_attributes(
    slug: item_data["slug"],
    full_name: item_data["full_name"],
    short_name: item_data["short_name"],
    categories: item_data["categories"] || [],
    links: item_data["links"] || [],
    images: item_data["images"] || []
  )
  item.save!

  # Create Property
  props_data = item_data["properties"]
  if props_data.present? && props_data.is_a?(Hash)
    property = Property.find_or_initialize_by(item_id: item.id)
    property.assign_attributes(
      properties_type: props_data["properties_type"],
      allowed_ammo: props_data["allowed_ammo"] || [],
      ammo_type: props_data["ammo_type"],
      armor_slots: props_data["armor_slots"] || [],
      armor_type: props_data["armor_type"],
      base_item: props_data["base_item"],
      caliber: props_data["caliber"],
      armor_class: props_data["class"],
      damage: props_data["damage"],
      default: props_data["default"],
      default_ammo: props_data["default_ammo"],
      default_preset: props_data["default_preset"],
      penetration_power: props_data["penetration_power"],
      presets: props_data["presets"] || [],
      slash_damage: props_data["slash_damage"],
      stab_damage: props_data["stab_damage"],
      category: props_data["category"],
      zones: props_data["zones"] || []
    )
    property.save!

    # Create Slots from properties.slots
    slots_data = props_data["slots"] || []
    slots_data.each do |slot_data|
      next unless slot_data.is_a?(Hash)

      filters = slot_data["filters"] || {}
      Slot.create!(
        property_id: property.id,
        name_id: slot_data["name_id"],
        required: slot_data["required"],
        allowed_items: filters["allowed_items"] || [],
        allowed_categories: filters["allowed_categories"] || [],
        excluded_categories: filters["excluded_categories"] || [],
        excluded_items: filters["excluded_items"] || []
      )
    end
  end

  # Create obtain_from records
  obtain_from = item_data["obtain_from"] || []
  obtain_from.each do |obtain|
    # ItemTaskRewards
    (obtain["task_rewards"] || []).each do |tr|
      ItemTaskReward.create!(
        item_id: item.id,
        task_id: tr["task_id"],
        task_name: tr["task_name"],
        reward_type: tr["reward_type"]
      )
    end

    # ItemHideouts
    (obtain["hideout"] || []).each do |h|
      ItemHideout.create!(
        item_id: item.id,
        station_name: h["station_name"],
        station_level: h["station_level"].to_i,
        quantity: h["quantity"].to_i
      )
    end

    # ItemBarters
    (obtain["barter"] || []).each do |b|
      ItemBarter.create!(
        item_id: item.id,
        trader_name: b["trader_name"],
        trader_level: trader_level_to_int(b["trader_level"])
      )
    end

    # ItemCurrencies
    (obtain["currency"] || []).each do |c|
      ItemCurrency.create!(
        item_id: item.id,
        trader_name: c["trader_name"],
        trader_level: trader_level_to_int(c["trader_level"]),
        currency: c["currency"]
      )
    end
  end
end

puts "Imported #{Item.count} items"

# ============================================
# Import Tasks
# ============================================
puts "Importing tasks..."

tasks_data = JSON.parse(File.read(json_dir.join("tasks_index.json")))

tasks_data.each do |task_data|
  bsg_id = task_data["bsg_id"]

  task = Task.find_or_initialize_by(bsg_id: bsg_id)
  task.assign_attributes(
    full_name: task_data["full_name"],
    name: task_data["name"],
    wiki_link: task_data["wiki_link"],
    given_by: task_data["given_by"],
    kappa_required: task_data["kappa_required"],
    lightkeeper_required: task_data["lightkeeper_required"]
  )
  task.save!

  # Create LeadsTo
  (task_data["leads_to"] || []).each do |lt|
    follow_up_task = Task.find_by(bsg_id: lt["task_id"])

    LeadsTo.create!(
      task_id: task.id,
      follow_up_task_id: follow_up_task&.id,
      follow_up_task_name: lt["task_name"]
    )
  end

  # Create Requirements
  (task_data["requirements"] || []).each do |req|
    requirement = Requirement.create!(
      task_id: task.id,
      player_level: req["player_level"].to_i
    )

    # Create PreviousTasks
    (req["previous_tasks"] || []).each do |pt|
      prev_task = Task.find_by(bsg_id: pt["task_id"])

      PreviousTask.create!(
        requirement_id: requirement.id,
        task_id: prev_task&.id,
        task_name: pt["task_name"]
      )
    end
  end

  # Create Rewards (start_rewards and finish_rewards)
  [ "start_rewards", "finish_rewards" ].each do |reward_type|
    (task_data[reward_type] || []).each do |reward_data|
      next if reward_data.nil?

      reward = Reward.create!(
        task_id: task.id,
        reward_type: reward_type
      )

      # LooseItems
      (reward_data["loose_items"] || []).each do |li|
        LooseItem.create!(
          reward_id: reward.id,
          item_id: li["item_id"],
          item_name: li["item_name"],
          count: li["count"].to_i
        )
      end

      # OfferUnlocks
      (reward_data["offer_unlocks"] || []).each do |ou|
        OfferUnlock.create!(
          reward_id: reward.id,
          item_id: ou["item_id"],
          item_name: ou["item_name"],
          trader_name: ou["trader_name"],
          trader_level: trader_level_to_int(ou["trader_level"])
        )
      end

      # BarterUnlocks with nested requirements and results
      (reward_data["barter_unlocks"] || []).each do |bu|
        result_items = bu.dig("result", 0, "items") || []
        first_item = result_items.first || {}

        barter_unlock = BarterUnlock.create!(
          reward_id: reward.id,
          item_id: first_item["item_id"],
          item_name: first_item["item_name"]
        )

        (bu["requirements"] || []).each do |req|
          barter_req = BarterRequirement.create!(
            barter_unlock_id: barter_unlock.id,
            trader_name: req["trader_name"],
            trader_level: trader_level_to_int(req["trader_level"])
          )

          (req["items"] || []).each do |ri|
            BarterRequirementItem.create!(
              barter_requirement_id: barter_req.id,
              item_id: ri["item_id"],
              item_name: ri["item_name"],
              count: ri["count"].to_i
            )
          end
        end

        (bu["result"] || []).each do |res|
          barter_result = BarterResult.create!(
            barter_unlock_id: barter_unlock.id
          )

          (res["items"] || []).each do |ri|
            BarterResultItem.create!(
              barter_result_id: barter_result.id,
              item_id: ri["item_id"],
              item_name: ri["item_name"]
            )
          end
        end
      end

      # CraftUnlocks with nested requirements and results
      (reward_data["craft_unlocks"] || []).each do |cu|
        # item_id can be at top level or inside result.items[0]
        result_items = cu.dig("result", 0, "items") || []
        first_result_item = result_items.first || {}
        item_id = cu["item_id"].presence || first_result_item["id"]
        item_name = cu["item_name"].presence || first_result_item["name"]

        craft_unlock = CraftUnlock.create!(
          reward_id: reward.id,
          item_id: item_id,
          item_name: item_name,
          hideout_station: cu["hideout_station"],
          station_level: cu["station_level"].to_i
        )

        (cu["requirements"] || []).each do |req|
          craft_req = CraftRequirement.create!(
            craft_unlock_id: craft_unlock.id,
            trader_name: req["trader_name"],
            trader_level: trader_level_to_int(req["trader_level"])
          )

          (req["items"] || []).each do |ri|
            CraftRequirementItem.create!(
              craft_requirement_id: craft_req.id,
              item_id: ri["id"],
              item_name: ri["name"],
              count: ri["quantity"].to_i
            )
          end
        end

        (cu["result"] || []).each do |res|
          craft_result = CraftResult.create!(
            craft_unlock_id: craft_unlock.id
          )

          (res["items"] || []).each do |ri|
            CraftResultItem.create!(
              craft_result_id: craft_result.id,
              item_id: ri["id"],
              item_name: ri["name"]
            )
          end
        end
      end
    end
  end
end

puts "Imported #{Task.count} tasks"
puts "Done!"
