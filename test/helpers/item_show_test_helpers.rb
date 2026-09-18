# frozen_string_literal: true

# Shared setup for the item page tests, split by concern across
# items_controller_show_test.rb (page chrome and per-class stats) and
# items_controller_show_acquisition_test.rb (unlocks, used-in and the panels
# around them).
module ItemShowTestHelpers
  # Every test starts by rendering a page and asserting it answered; the pair is
  # not worth repeating.
  def get_ok(path)
    get path
    assert_response :success
  end

  def create_show_item
    create_item("Test Item", short_name: "TI")
  end
end
