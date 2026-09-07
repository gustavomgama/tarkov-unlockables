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

ActiveRecord::Schema[8.1].define(version: 2026_09_05_214828) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "barter_requirement_items", force: :cascade do |t|
    t.bigint "barter_requirement_id"
    t.string "item_id"
    t.string "item_name"
    t.integer "count"
    t.index ["barter_requirement_id"], name: "index_barter_requirement_items_on_barter_requirement_id"
  end

  create_table "barter_requirements", force: :cascade do |t|
    t.bigint "barter_unlock_id"
    t.string "trader_name"
    t.string "trader_level"
    t.index ["barter_unlock_id"], name: "index_barter_requirements_on_barter_unlock_id"
  end

  create_table "barter_result_items", force: :cascade do |t|
    t.bigint "barter_result_id"
    t.string "item_id"
    t.string "item_name"
    t.index ["barter_result_id"], name: "index_barter_result_items_on_barter_result_id"
  end

  create_table "barter_results", force: :cascade do |t|
    t.bigint "barter_unlock_id"
    t.index ["barter_unlock_id"], name: "index_barter_results_on_barter_unlock_id"
  end

  create_table "barter_unlocks", force: :cascade do |t|
    t.bigint "reward_id"
    t.string "item_id"
    t.string "item_name"
    t.index ["reward_id"], name: "index_barter_unlocks_on_reward_id"
  end

  create_table "craft_requirement_items", force: :cascade do |t|
    t.bigint "craft_requirement_id"
    t.string "item_id"
    t.string "item_name"
    t.integer "count"
    t.index ["craft_requirement_id"], name: "index_craft_requirement_items_on_craft_requirement_id"
  end

  create_table "craft_requirements", force: :cascade do |t|
    t.bigint "craft_unlock_id"
    t.string "trader_name"
    t.string "trader_level"
    t.index ["craft_unlock_id"], name: "index_craft_requirements_on_craft_unlock_id"
  end

  create_table "craft_result_items", force: :cascade do |t|
    t.bigint "craft_result_id"
    t.string "item_id"
    t.string "item_name"
    t.index ["craft_result_id"], name: "index_craft_result_items_on_craft_result_id"
  end

  create_table "craft_results", force: :cascade do |t|
    t.bigint "craft_unlock_id"
    t.index ["craft_unlock_id"], name: "index_craft_results_on_craft_unlock_id"
  end

  create_table "craft_unlocks", force: :cascade do |t|
    t.bigint "reward_id"
    t.string "item_id"
    t.string "item_name"
    t.string "hideout_station"
    t.integer "station_level"
    t.index ["reward_id"], name: "index_craft_unlocks_on_reward_id"
  end

  create_table "item_barters", force: :cascade do |t|
    t.bigint "item_id"
    t.string "trader_name"
    t.string "trader_level"
    t.index ["item_id"], name: "index_item_barters_on_item_id"
  end

  create_table "item_currencies", force: :cascade do |t|
    t.bigint "item_id"
    t.string "trader_name"
    t.string "trader_level"
    t.string "currency"
    t.index ["item_id"], name: "index_item_currencies_on_item_id"
  end

  create_table "item_hideouts", force: :cascade do |t|
    t.bigint "item_id"
    t.string "station_name"
    t.integer "station_level"
    t.integer "quantity"
    t.index ["item_id"], name: "index_item_hideouts_on_item_id"
  end

  create_table "item_task_rewards", force: :cascade do |t|
    t.bigint "item_id"
    t.string "task_id"
    t.string "task_name"
    t.string "reward_type"
    t.index ["item_id"], name: "index_item_task_rewards_on_item_id"
  end

  create_table "items", force: :cascade do |t|
    t.string "bsg_id"
    t.string "slug"
    t.string "full_name"
    t.string "short_name"
    t.text "categories", default: [], array: true
    t.text "links", default: [], array: true
    t.text "images", default: [], array: true
  end

  create_table "leads_tos", force: :cascade do |t|
    t.bigint "task_id"
    t.string "follow_up_task_id"
    t.string "follow_up_task_name"
    t.index ["task_id"], name: "index_leads_tos_on_task_id"
  end

  create_table "loose_items", force: :cascade do |t|
    t.bigint "reward_id"
    t.string "item_id"
    t.string "item_name"
    t.integer "count"
    t.index ["reward_id"], name: "index_loose_items_on_reward_id"
  end

  create_table "offer_unlocks", force: :cascade do |t|
    t.bigint "reward_id"
    t.string "item_id"
    t.string "item_name"
    t.string "trader_name"
    t.string "trader_level"
    t.index ["reward_id"], name: "index_offer_unlocks_on_reward_id"
  end

  create_table "previous_tasks", force: :cascade do |t|
    t.bigint "requirement_id"
    t.string "task_id"
    t.string "task_name"
    t.index ["requirement_id"], name: "index_previous_tasks_on_requirement_id"
  end

  create_table "properties", force: :cascade do |t|
    t.bigint "item_id"
    t.string "properties_type"
    t.text "allowed_ammo", default: [], array: true
    t.string "ammo_type"
    t.text "armor_slots", default: [], array: true
    t.string "armor_type"
    t.string "base_item"
    t.string "caliber"
    t.integer "armor_class"
    t.integer "damage"
    t.boolean "default"
    t.string "default_ammo"
    t.string "default_preset"
    t.integer "penetration_power"
    t.text "presets", default: [], array: true
    t.integer "slash_damage"
    t.integer "stab_damage"
    t.string "category"
    t.text "zones", default: [], array: true
    t.index ["item_id"], name: "index_properties_on_item_id"
  end

  create_table "requirements", force: :cascade do |t|
    t.bigint "task_id"
    t.integer "player_level"
    t.integer "previous_tasks_count", default: 0
    t.index ["task_id"], name: "index_requirements_on_task_id"
  end

  create_table "rewards", force: :cascade do |t|
    t.bigint "task_id"
    t.string "reward_type"
    t.index ["task_id"], name: "index_rewards_on_task_id"
  end

  create_table "slots", force: :cascade do |t|
    t.bigint "property_id"
    t.string "name_id"
    t.boolean "required"
    t.text "allowed_items", default: [], array: true
    t.text "allowed_categories", default: [], array: true
    t.text "excluded_categories", default: [], array: true
    t.text "excluded_items", default: [], array: true
    t.index ["property_id"], name: "index_slots_on_property_id"
  end

  create_table "tasks", force: :cascade do |t|
    t.string "bsg_id"
    t.string "full_name"
    t.string "name"
    t.string "wiki_link"
    t.string "given_by"
    t.boolean "kappa_required"
    t.boolean "lightkeeper_required"
    t.integer "leads_tos_count", default: 0
  end

  add_foreign_key "barter_requirement_items", "barter_requirements"
  add_foreign_key "barter_requirements", "barter_unlocks"
  add_foreign_key "barter_result_items", "barter_results"
  add_foreign_key "barter_results", "barter_unlocks"
  add_foreign_key "barter_unlocks", "rewards"
  add_foreign_key "craft_requirement_items", "craft_requirements"
  add_foreign_key "craft_requirements", "craft_unlocks"
  add_foreign_key "craft_result_items", "craft_results"
  add_foreign_key "craft_results", "craft_unlocks"
  add_foreign_key "craft_unlocks", "rewards"
  add_foreign_key "item_barters", "items"
  add_foreign_key "item_currencies", "items"
  add_foreign_key "item_hideouts", "items"
  add_foreign_key "item_task_rewards", "items"
  add_foreign_key "leads_tos", "tasks"
  add_foreign_key "loose_items", "rewards"
  add_foreign_key "offer_unlocks", "rewards"
  add_foreign_key "previous_tasks", "requirements"
  add_foreign_key "properties", "items"
  add_foreign_key "requirements", "tasks"
  add_foreign_key "rewards", "tasks"
  add_foreign_key "slots", "properties"
end
