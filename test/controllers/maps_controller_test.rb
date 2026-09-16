require "test_helper"

class MapsControllerTest < ActionDispatch::IntegrationTest
  test "index lists maps with their raid info" do
    map = Map.create!(bsg_id: "ix-#{SecureRandom.hex(4)}", slug: "ix-#{SecureRandom.hex(4)}",
                      name: "Index Map", raid_duration: 40, players: "7-10",
                      bosses: [ { "name" => "Test Boss" } ])

    get maps_url

    assert_response :success
    assert_match "Index Map", response.body
    assert_match "Test Boss", response.body
    assert_select "a[href=?]", map_path(map.slug)
  ensure
    map&.destroy
  end

  test "show renders bosses, extracts and transits" do
    map = Map.create!(
      bsg_id: "sh-#{SecureRandom.hex(4)}", slug: "sh-#{SecureRandom.hex(4)}",
      name: "Show Map", raid_duration: 45, players: "7-12",
      bosses: [ { "mob" => "bossBully", "name" => "Reshala", "spawn_chance" => 0.6,
                  "escorts" => [ { "mob" => "followerBully", "name" => "Reshala Guard",
                                   "amount" => [ { "chance" => 1, "count" => 4 } ] } ] } ],
      extracts: [ { "id" => "e1", "name" => "ZB-1011", "faction" => "shared" },
                  { "id" => "e2", "name" => "Crossroads", "faction" => "pmc" } ],
      transits: [ { "id" => "1", "name" => "Transit to Reserve", "map_name" => "Reserve" } ]
    )

    get map_url(map.slug)

    assert_response :success
    assert_select "h1", text: "Show Map"
    assert_select "h2", text: "Bosses"
    assert_match "Reshala", response.body
    assert_match "60%", response.body
    assert_match "Reshala Guard ×4", response.body
    assert_select "h2", text: "Extracts"
    assert_match "ZB-1011", response.body
    assert_match "Transit to Reserve", response.body
  ensure
    map&.destroy
  end

  test "show returns 404 for an unknown map" do
    get map_url("nope")
    assert_response :not_found
    assert_select "h1", text: "404"
  end
end
