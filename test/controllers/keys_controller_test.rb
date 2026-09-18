require "test_helper"

class KeysControllerTest < ActionDispatch::IntegrationTest
  test "index lists each key with the quests that need it" do
    key = Item.create!(bsg_id: "kc-#{SecureRandom.hex(4)}", full_name: "Dorm Room Key", short_name: "DRK")
    task = Task.create!(bsg_id: "kc-t-#{SecureRandom.hex(4)}", full_name: "Key Quest", name: "key-quest",
                        given_by: "Prapor",
                        needed_keys: [ { "map_name" => "Customs", "item_id" => key.id,
                                         "item_name" => key.full_name } ])

    get keys_url

    assert_response :success
    assert_select "h1", text: "Quest keys"
    assert_select "a[href=?]", item_path(key), text: "Dorm Room Key"
    assert_select "a[href=?]", task_path(task), text: "Key Quest"
    assert_match "Customs", response.body
  ensure
    task&.destroy
    key&.destroy
  end

  # A needed_key without a map name is still a key the quest asks for; only the
  # map chip is skipped.
  test "index lists a key that names no map" do
    key = Item.create!(bsg_id: "kc2-#{SecureRandom.hex(4)}", full_name: "Mapless Key", short_name: "MK")
    task = Task.create!(bsg_id: "kc2-t-#{SecureRandom.hex(4)}", full_name: "Mapless Quest", name: "mapless-quest",
                        given_by: "Prapor",
                        needed_keys: [ { "item_id" => key.id, "item_name" => key.full_name } ])

    get keys_url

    assert_response :success
    assert_select "a[href=?]", item_path(key), text: "Mapless Key"
    assert_select "a[href=?]", task_path(task), text: "Mapless Quest"
  ensure
    task&.destroy
    key&.destroy
  end

  # A quest can name the same key twice (two maps); the task is listed once.
  test "index lists a quest once when it names the same key twice" do
    key = Item.create!(bsg_id: "kc3-#{SecureRandom.hex(4)}", full_name: "Twice Key", short_name: "TK")
    task = Task.create!(bsg_id: "kc3-t-#{SecureRandom.hex(4)}", full_name: "Twice Quest", name: "twice-quest",
                        given_by: "Prapor",
                        needed_keys: [ { "map_name" => "Customs", "item_id" => key.id, "item_name" => key.full_name },
                                       { "map_name" => "Woods", "item_id" => key.id, "item_name" => key.full_name } ])

    get keys_url

    assert_response :success
    assert_select "a[href=?]", task_path(task), text: "Twice Quest", count: 1
  ensure
    task&.destroy
    key&.destroy
  end

  test "index renders when no quest needs a key" do
    get keys_url

    assert_response :success
    assert_select "h1", text: "Quest keys"
  end
end
