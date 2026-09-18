require "application_system_test_case"

class LayoutTest < ApplicationSystemTestCase
  test "the header nav does not overflow at the tablet breakpoint" do
    visit items_path
    use_viewport(768, 900)

    overflow = page.evaluate_script(
      "document.querySelector('header').scrollWidth - document.querySelector('header').clientWidth"
    )

    assert_operator overflow, :<=, 0, "header overflows by #{overflow}px at 768px"
  end
end
