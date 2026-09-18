require "test_helper"

class StationsControllerTest < ActionDispatch::IntegrationTest
  test "index lists stations with their level count" do
    station = HideoutStation.create!(bsg_id: "ix-#{SecureRandom.hex(4)}", slug: "ix-#{SecureRandom.hex(4)}",
                                     name: "Test Station")
    station.hideout_levels.create!(level: 1)

    get stations_url

    assert_response :success
    assert_match "Test Station", response.body
    assert_select "a[href=?]", station_path(station.slug)
  ensure
    station&.destroy
  end

  test "show lists each level's build cost" do
    station = HideoutStation.create!(bsg_id: "sh-#{SecureRandom.hex(4)}", slug: "sh-#{SecureRandom.hex(4)}",
                                     name: "Build Station")
    item = Item.create!(bsg_id: "sh-i-#{SecureRandom.hex(4)}", full_name: "Build Widget", short_name: "BW")
    level = station.hideout_levels.create!(
      level: 2, construction_time: 3600,
      station_requirements: [ { "station_name" => "Generator", "level" => 1 } ],
      trader_requirements: [ { "name" => "Mechanic", "level" => 2 } ]
    )
    level.hideout_item_requirements.create!(item: item, item_name: item.full_name, count: 3, found_in_raid: true)
    crafted = Item.create!(bsg_id: "sh-c-#{SecureRandom.hex(4)}", full_name: "Crafted Thing", short_name: "CT")
    ItemHideout.create!(item: crafted, station: "Build Station", level: 2, count: 1)

    get station_url(station.slug)

    assert_response :success
    assert_select "h1", text: "Build Station"
    assert_select "h2", text: "Level 2"
    assert_select "a[href=?]", item_path(item), text: "Build Widget"
    assert_select ".srcrow", text: /Crafts/
    assert_select "a[href=?]", item_path(crafted), text: "Crafted Thing"
    assert_match "found in raid", response.body
    assert_select "a[href=?]", station_path("generator"), text: "Generator"
    assert_match "Mechanic", response.body
    assert_match "about 1 hour", response.body
  ensure
    station&.destroy
    item&.destroy
    crafted&.destroy
  end

  test "show returns 404 for an unknown station" do
    get station_url("nope")
    assert_response :not_found
    assert_select "h1", text: "404"
  end

  # A conditional request that is still fresh answers 304 before the preloads
  # run (the `return if performed?` branch).
  test "show answers a fresh conditional request with 304" do
    station = HideoutStation.create!(bsg_id: "cond-#{SecureRandom.hex(4)}", slug: "cond-#{SecureRandom.hex(4)}",
                                     name: "Conditional Station")

    get station_url(station.slug)
    assert_response :success

    get station_url(station.slug), headers: { "If-None-Match" => response.headers["ETag"] }
    assert_response :not_modified
  ensure
    station&.destroy
  end
end
