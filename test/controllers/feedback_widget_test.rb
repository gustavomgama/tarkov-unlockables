require "test_helper"

class FeedbackWidgetTest < ActionDispatch::IntegrationTest
  test "site footer renders the utterances feedback widget" do
    get root_url

    assert_response :success
    assert_includes response.body, %(src="https://utteranc.es/client.js")
    assert_includes response.body, %(repo="gustavomgama/tarkov-unlockables")
    assert_match(/issue-number="\d+"/, response.body)
  end

  test "the widget ships in the layout, so it shows on every page" do
    get tasks_url

    assert_response :success
    assert_includes response.body, %(src="https://utteranc.es/client.js")
  end

  test "the widget area is height-capped so a long thread cannot push the footer away" do
    get root_url

    # Roughly five comments before the wrapper scrolls instead of growing.
    assert_includes response.body, "max-h-[600px]"
    assert_select "div.max-w-3xl.overflow-y-auto script[src*='utteranc.es']"
  end
end
