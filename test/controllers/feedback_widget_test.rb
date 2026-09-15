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
end
