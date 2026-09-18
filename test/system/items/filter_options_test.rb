require "application_system_test_case"

# The Category filter only gets a narrowing box when a menu has more than 12
# options. Fixtures (test/fixtures/items.yml) carry enough categories for that,
# so this stays fixture-only: the app runs in a second thread and a test that
# writes rows leaves a transaction idle past
# idle_in_transaction_session_timeout, killing later queries in the run.
class FilterOptionsTest < ApplicationSystemTestCase
  test "typing narrows a long option menu without submitting" do
    visit items_path

    group = find(".filter-group", text: "Category")
    group.find("summary").click

    box = group.find("input[data-filter-options-target='input']")
    box.fill_in with: "uniquecat05"

    shown = group.all("[data-filter-options-target='option']", visible: :visible)
    assert_equal 1, shown.size
    assert_match(/Uniquecat05/, shown.first.text)

    # Enter in the box must be stopped, not submit the enclosing filter form:
    # a navigation would re-render the group closed.
    box.send_keys(:enter)
    assert_selector ".filter-group[open]"
  end
end
