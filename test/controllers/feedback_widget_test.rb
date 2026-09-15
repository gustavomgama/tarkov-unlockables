require "test_helper"

class FeedbackWidgetTest < ActionDispatch::IntegrationTest
  test "site footer offers the utterances feedback widget" do
    get root_url

    assert_response :success
    assert_includes response.body, 'data-controller="feedback"'
    assert_includes response.body, %(src="https://utteranc.es/client.js")
    assert_includes response.body, %(repo="gustavomgama/tarkov-unlockables")
    assert_match(/issue-number="\d+"/, response.body)
  end

  test "the widget script is inert until the section is expanded" do
    get root_url

    # The <script> lives inside a <template> so no third-party iframe loads
    # on a normal page view; the lazy controller clones it on demand.
    assert_includes response.body, "<template"
    assert_includes response.body, "controllers/feedback_controller"
  end
end
