# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_17_000000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

  create_table "barter_requirement_items", force: :cascade do |t|
    t.bigint "barter_requirement_id", null: false
    t.bigint "item_id"
    t.string "item_name"
    t.integer "count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["barter_requirement_id"], name: "index_barter_requirement_items_on_barter_requirement_id"
    t.index ["item_id"], name: "index_barter_requirement_items_on_item_id"
  end

  create_table "barter_requirements", force: :cascade do |t|
    t.bigint "barter_unlock_id", null: false
    t.string "trader_name"
    t.string "trader_level"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["barter_unlock_id"], name: "index_barter_requirements_on_barter_unlock_id"
  end

  create_table "barter_result_items", force: :cascade do |t|
    t.bigint "barter_result_id", null: false
    t.bigint "item_id"
    t.string "item_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["barter_result_id"], name: "index_barter_result_items_on_barter_result_id"
    t.index ["item_id"], name: "index_barter_result_items_on_item_id"
  end

  create_table "barter_results", force: :cascade do |t|
    t.bigint "barter_unlock_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["barter_unlock_id"], name: "index_barter_results_on_barter_unlock_id"
  end

  create_table "barter_unlocks", force: :cascade do |t|
    t.bigint "reward_id", null: false
    t.bigint "item_id"
    t.string "item_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["item_id"], name: "index_barter_unlocks_on_item_id"
    t.index ["reward_id"], name: "index_barter_unlocks_on_reward_id"
  end

  create_table "craft_requirement_items", force: :cascade do |t|
    t.bigint "craft_requirement_id", null: false
    t.bigint "item_id"
    t.string "item_name"
    t.integer "count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["craft_requirement_id"], name: "index_craft_requirement_items_on_craft_requirement_id"
    t.index ["item_id"], name: "index_craft_requirement_items_on_item_id"
  end

  create_table "craft_requirements", force: :cascade do |t|
    t.bigint "craft_unlock_id", null: false
    t.string "trader_name"
    t.string "trader_level"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["craft_unlock_id"], name: "index_craft_requirements_on_craft_unlock_id"
  end

  create_table "craft_result_items", force: :cascade do |t|
    t.bigint "craft_result_id", null: false
    t.bigint "item_id"
    t.string "item_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["craft_result_id"], name: "index_craft_result_items_on_craft_result_id"
    t.index ["item_id"], name: "index_craft_result_items_on_item_id"
  end

  create_table "craft_results", force: :cascade do |t|
    t.bigint "craft_unlock_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["craft_unlock_id"], name: "index_craft_results_on_craft_unlock_id"
  end

  create_table "craft_unlocks", force: :cascade do |t|
    t.bigint "reward_id", null: false
    t.bigint "item_id"
    t.string "item_name"
    t.string "hideout_station"
    t.integer "station_level"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["item_id"], name: "index_craft_unlocks_on_item_id"
    t.index ["reward_id"], name: "index_craft_unlocks_on_reward_id"
  end

  create_table "favorite_items", force: :cascade do |t|
    t.bigint "item_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["item_id"], name: "index_favorite_items_on_item_id"
  end

  create_table "hideout_item_requirements", force: :cascade do |t|
    t.bigint "hideout_level_id", null: false
    t.bigint "item_id"
    t.string "item_name"
    t.integer "count"
    t.boolean "found_in_raid", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["hideout_level_id"], name: "index_hideout_item_requirements_on_hideout_level_id"
    t.index ["item_id"], name: "index_hideout_item_requirements_on_item_id"
  end

  create_table "hideout_levels", force: :cascade do |t|
    t.bigint "hideout_station_id", null: false
    t.integer "level"
    t.integer "construction_time"
    t.jsonb "station_requirements", default: [], null: false
    t.jsonb "trader_requirements", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["hideout_station_id"], name: "index_hideout_levels_on_hideout_station_id"
  end

  create_table "hideout_stations", force: :cascade do |t|
    t.string "bsg_id"
    t.string "slug"
    t.string "name"
    t.string "image_url"
    t.integer "area_type"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bsg_id"], name: "index_hideout_stations_on_bsg_id", unique: true
    t.index ["slug"], name: "index_hideout_stations_on_slug", unique: true
  end

  create_table "item_barter_requirements", force: :cascade do |t|
    t.bigint "item_barter_id", null: false
    t.bigint "item_id"
    t.string "item_name"
    t.integer "count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["item_barter_id"], name: "index_item_barter_requirements_on_item_barter_id"
    t.index ["item_id"], name: "index_item_barter_requirements_on_item_id"
  end

  create_table "item_barters", force: :cascade do |t|
    t.bigint "item_id", null: false
    t.string "trader"
    t.string "trader_level"
    t.string "currency"
    t.integer "cost"
    t.string "item_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "barter_id"
    t.integer "count", default: 1, null: false
    t.integer "buy_limit"
    t.bigint "restock_amount"
    t.bigint "task_id"
    t.index ["barter_id"], name: "index_item_barters_on_barter_id"
    t.index ["item_id"], name: "index_item_barters_on_item_id"
    t.index ["task_id"], name: "index_item_barters_on_task_id"
  end

  create_table "item_currencies", force: :cascade do |t|
    t.bigint "item_id", null: false
    t.string "trader"
    t.string "currency"
    t.integer "min_trader_level"
    t.boolean "task_unlock", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "task_id"
    t.bigint "price"
    t.bigint "price_rub"
    t.integer "buy_limit"
    t.index ["currency"], name: "index_item_currencies_on_currency"
    t.index ["item_id"], name: "index_item_currencies_on_item_id"
    t.index ["task_id"], name: "index_item_currencies_on_task_id"
    t.index ["trader"], name: "index_item_currencies_on_trader"
  end

  create_table "item_hideout_requirements", force: :cascade do |t|
    t.bigint "item_hideout_id", null: false
    t.bigint "item_id"
    t.string "item_name"
    t.integer "count"
    t.boolean "is_tool", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["item_hideout_id"], name: "index_item_hideout_requirements_on_item_hideout_id"
    t.index ["item_id"], name: "index_item_hideout_requirements_on_item_id"
  end

  create_table "item_hideouts", force: :cascade do |t|
    t.bigint "item_id", null: false
    t.string "station"
    t.integer "level"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "craft_id"
    t.integer "count", default: 1, null: false
    t.integer "duration"
    t.bigint "task_id"
    t.index ["craft_id"], name: "index_item_hideouts_on_craft_id"
    t.index ["item_id"], name: "index_item_hideouts_on_item_id"
    t.index ["task_id"], name: "index_item_hideouts_on_task_id"
  end

  create_table "item_slot_allowed_items", force: :cascade do |t|
    t.bigint "item_slot_id", null: false
    t.bigint "item_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["item_id"], name: "index_item_slot_allowed_items_on_item_id"
    t.index ["item_slot_id"], name: "index_item_slot_allowed_items_on_item_slot_id"
  end

  create_table "item_slots", force: :cascade do |t|
    t.bigint "item_id", null: false
    t.string "slot_id"
    t.string "name_id"
    t.string "name"
    t.boolean "required", default: false, null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["item_id"], name: "index_item_slots_on_item_id"
  end

  create_table "item_task_rewards", force: :cascade do |t|
    t.bigint "item_id", null: false
    t.bigint "task_id"
    t.string "task_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["item_id"], name: "index_item_task_rewards_on_item_id"
    t.index ["task_id"], name: "index_item_task_rewards_on_task_id"
  end

  create_table "items", force: :cascade do |t|
    t.string "type", default: "Item::Generic", null: false
    t.string "bsg_id"
    t.string "slug"
    t.string "full_name"
    t.string "short_name"
    t.string "wiki_title"
    t.text "categories", default: [], array: true
    t.text "links", default: [], array: true
    t.text "images", default: [], array: true
    t.jsonb "data", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "search_text", default: "", null: false
    t.index ["bsg_id"], name: "index_items_on_bsg_id", unique: true
    t.index ["categories"], name: "index_items_on_categories", using: :gin
    t.index ["data"], name: "index_items_on_data", using: :gin
    t.index ["full_name"], name: "index_items_on_full_name"
    t.index ["search_text"], name: "index_items_on_search_text_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["slug"], name: "index_items_on_slug"
    t.index ["type"], name: "index_items_on_type"
  end

  create_table "leads_tos", force: :cascade do |t|
    t.bigint "task_id", null: false
    t.bigint "follow_up_task_id"
    t.string "follow_up_task_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["follow_up_task_id"], name: "index_leads_tos_on_follow_up_task_id"
    t.index ["task_id"], name: "index_leads_tos_on_task_id"
  end

  create_table "loose_items", force: :cascade do |t|
    t.bigint "reward_id", null: false
    t.bigint "item_id"
    t.string "item_name"
    t.integer "count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["item_id"], name: "index_loose_items_on_item_id"
    t.index ["reward_id"], name: "index_loose_items_on_reward_id"
  end

  create_table "maps", force: :cascade do |t|
    t.string "bsg_id"
    t.string "slug"
    t.string "name"
    t.string "name_id"
    t.string "wiki_link"
    t.text "description"
    t.integer "raid_duration"
    t.string "players"
    t.jsonb "enemies", default: [], null: false
    t.jsonb "bosses", default: [], null: false
    t.jsonb "extracts", default: [], null: false
    t.jsonb "transits", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bsg_id"], name: "index_maps_on_bsg_id", unique: true
    t.index ["slug"], name: "index_maps_on_slug", unique: true
  end

  create_table "offer_unlocks", force: :cascade do |t|
    t.bigint "reward_id", null: false
    t.bigint "item_id"
    t.string "item_name"
    t.string "trader_name"
    t.string "trader_level"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["item_id"], name: "index_offer_unlocks_on_item_id"
    t.index ["reward_id"], name: "index_offer_unlocks_on_reward_id"
  end

  create_table "previous_tasks", force: :cascade do |t|
    t.bigint "requirement_id", null: false
    t.bigint "task_id"
    t.string "task_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "alternative", default: false, null: false
    t.index ["requirement_id"], name: "index_previous_tasks_on_requirement_id"
    t.index ["task_id"], name: "index_previous_tasks_on_task_id"
  end

  create_table "requirements", force: :cascade do |t|
    t.bigint "task_id", null: false
    t.integer "player_level"
    t.integer "previous_tasks_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "trader_level", default: [], null: false
    t.index ["task_id"], name: "index_requirements_on_task_id"
  end

  create_table "rewards", force: :cascade do |t|
    t.bigint "task_id", null: false
    t.string "reward_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "data", default: {}, null: false
    t.index ["task_id"], name: "index_rewards_on_task_id"
  end

  create_table "task_objective_items", force: :cascade do |t|
    t.bigint "task_objective_id", null: false
    t.bigint "item_id"
    t.string "item_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["item_id"], name: "index_task_objective_items_on_item_id"
    t.index ["task_objective_id"], name: "index_task_objective_items_on_task_objective_id"
  end

  create_table "task_objectives", force: :cascade do |t|
    t.bigint "task_id", null: false
    t.string "objective_id"
    t.string "objective_type"
    t.text "description"
    t.integer "count"
    t.boolean "optional", default: false, null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["task_id"], name: "index_task_objectives_on_task_id"
  end

  create_table "tasks", force: :cascade do |t|
    t.string "bsg_id"
    t.string "full_name"
    t.string "name"
    t.string "wiki_link"
    t.string "given_by"
    t.boolean "kappa_required"
    t.boolean "lightkeeper_required"
    t.integer "leads_tos_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "search_text", default: "", null: false
    t.string "map_id"
    t.string "map_name"
    t.integer "experience"
    t.string "faction"
    t.jsonb "needed_keys", default: [], null: false
    t.index ["full_name"], name: "index_tasks_on_full_name"
    t.index ["given_by"], name: "index_tasks_on_given_by"
    t.index ["map_name"], name: "index_tasks_on_map_name"
    t.index ["name"], name: "index_tasks_on_name"
    t.index ["search_text"], name: "index_tasks_on_search_text_trgm", opclass: :gin_trgm_ops, using: :gin
  end

  create_table "trader_levels", force: :cascade do |t|
    t.bigint "trader_id", null: false
    t.integer "level"
    t.integer "required_player_level"
    t.float "required_reputation"
    t.float "required_commerce"
    t.float "pay_rate"
    t.float "insurance_rate"
    t.float "repair_cost_multiplier"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["trader_id"], name: "index_trader_levels_on_trader_id"
  end

  create_table "traders", force: :cascade do |t|
    t.string "bsg_id"
    t.string "slug"
    t.string "name"
    t.text "description"
    t.string "currency"
    t.string "image_url"
    t.integer "task_count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bsg_id"], name: "index_traders_on_bsg_id", unique: true
    t.index ["slug"], name: "index_traders_on_slug", unique: true
  end

  add_foreign_key "barter_requirement_items", "barter_requirements"
  add_foreign_key "barter_requirement_items", "items"
  add_foreign_key "barter_requirements", "barter_unlocks"
  add_foreign_key "barter_result_items", "barter_results"
  add_foreign_key "barter_result_items", "items"
  add_foreign_key "barter_results", "barter_unlocks"
  add_foreign_key "barter_unlocks", "items"
  add_foreign_key "barter_unlocks", "rewards"
  add_foreign_key "craft_requirement_items", "craft_requirements"
  add_foreign_key "craft_requirement_items", "items"
  add_foreign_key "craft_requirements", "craft_unlocks"
  add_foreign_key "craft_result_items", "craft_results"
  add_foreign_key "craft_result_items", "items"
  add_foreign_key "craft_results", "craft_unlocks"
  add_foreign_key "craft_unlocks", "items"
  add_foreign_key "craft_unlocks", "rewards"
  add_foreign_key "favorite_items", "items", on_delete: :restrict
  add_foreign_key "hideout_item_requirements", "hideout_levels"
  add_foreign_key "hideout_item_requirements", "items"
  add_foreign_key "hideout_levels", "hideout_stations"
  add_foreign_key "item_barter_requirements", "item_barters", on_delete: :cascade
  add_foreign_key "item_barter_requirements", "items"
  add_foreign_key "item_barters", "items"
  add_foreign_key "item_barters", "tasks"
  add_foreign_key "item_currencies", "items"
  add_foreign_key "item_currencies", "tasks"
  add_foreign_key "item_hideout_requirements", "item_hideouts", on_delete: :cascade
  add_foreign_key "item_hideout_requirements", "items"
  add_foreign_key "item_hideouts", "items"
  add_foreign_key "item_hideouts", "tasks"
  add_foreign_key "item_slot_allowed_items", "item_slots", on_delete: :cascade
  add_foreign_key "item_slot_allowed_items", "items"
  add_foreign_key "item_slots", "items"
  add_foreign_key "item_task_rewards", "items"
  add_foreign_key "item_task_rewards", "tasks"
  add_foreign_key "leads_tos", "tasks"
  add_foreign_key "leads_tos", "tasks", column: "follow_up_task_id"
  add_foreign_key "loose_items", "items"
  add_foreign_key "loose_items", "rewards"
  add_foreign_key "offer_unlocks", "items"
  add_foreign_key "offer_unlocks", "rewards"
  add_foreign_key "previous_tasks", "requirements"
  add_foreign_key "previous_tasks", "tasks"
  add_foreign_key "requirements", "tasks"
  add_foreign_key "rewards", "tasks"
  add_foreign_key "task_objective_items", "items"
  add_foreign_key "task_objective_items", "task_objectives"
  add_foreign_key "task_objectives", "tasks"
  add_foreign_key "trader_levels", "traders"
end
