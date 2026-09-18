require "test_helper"

class FeedbackWidgetTest < ActionDispatch::IntegrationTest
  # The ampersands are escaped in the attribute, as HTML requires; the browser
  # decodes them back before Tally's widget reads the value.
  TALLY_EMBED_SRC = "https://tally.so/embed/Pd77Md?alignLeft=1&amp;hideTitle=1&amp;transparentBackground=1&amp;dynamicHeight=1".freeze
  TALLY_IFRAME_SELECTOR = "iframe[data-tally-src*='tally.so/embed/Pd77Md']".freeze

  test "the footer embeds the Tally form in-page as an iframe" do
    get root_url

    assert_response :success
    assert_select TALLY_IFRAME_SELECTOR, count: 1
    assert_includes response.body, TALLY_EMBED_SRC
  end

  # A copy-paste once shipped the Tally block and the "Public thread" intro
  # twice, with an unmatched </div>; assert one of each so it cannot come back.
  test "each feedback channel is embedded exactly once" do
    get root_url

    assert_select TALLY_IFRAME_SELECTOR, count: 1
    assert_equal 1, response.body.scan("tally.so/widgets/embed.js").size
    assert_equal 1, response.body.scan("utteranc.es/client.js").size
    assert_equal 1, response.body.scan("Public thread").size
  end

  test "the Tally form is embedded, never linked off-site" do
    get root_url

    assert_select "a[href*='tally.so']", count: 0
    assert_not_includes response.body, %(href="https://tally.so/r/)
  end

  test "the Tally embed loads the resizing widget so the iframe fits its form" do
    get root_url

    assert_includes response.body, "https://tally.so/widgets/embed.js"
    assert_includes response.body, "dynamicHeight=1"
  end

  test "the Tally iframe is labelled for screen readers" do
    get root_url

    assert_select "#{TALLY_IFRAME_SELECTOR}[title='Private feedback form']"
  end

  test "the footer still renders the public utterances thread" do
    get root_url

    assert_response :success
    assert_includes response.body, %(src="https://utteranc.es/client.js")
    assert_includes response.body, %(repo="gustavomgama/tarkov-unlockables")
    assert_match(/issue-number="\d+"/, response.body)
  end

  test "the thread area is height-capped so a long thread cannot push the footer away" do
    get root_url

    assert_includes response.body, "max-h-[600px]"
    assert_select "div.max-w-3xl.overflow-y-auto script[src*='utteranc.es']"
  end

  test "both feedback channels ship in the layout, so they show on every page" do
    get tasks_url

    assert_response :success
    assert_select TALLY_IFRAME_SELECTOR
    assert_includes response.body, %(src="https://utteranc.es/client.js")
  end
end
