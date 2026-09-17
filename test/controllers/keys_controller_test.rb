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

  test "index renders when no quest needs a key" do
    get keys_url

    assert_response :success
    assert_select "h1", text: "Quest keys"
  end
end
