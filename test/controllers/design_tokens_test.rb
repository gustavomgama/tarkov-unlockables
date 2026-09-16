require "test_helper"

# The palette lives in app/views/shared/_design_tokens. Both layouts render it,
# and the admin layout adds its own extras on top. Before this, the admin kept
# a second hand-maintained palette that had already drifted from the site's.
class DesignTokensTest < ActionDispatch::IntegrationTest
  OLD_PALETTE = %w[#d2af78 #e6c58c].freeze
  ACCENT = "--accent: #c9a84c".freeze

  def style_block(body)
    body[body.index("<style>")..body.index("</style>")]
  end

  def admin_headers
    password = ENV.fetch("ADMIN_PASSWORD") { "admin" }
    { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", password) }
  end

  test "the public layout carries the shared palette once" do
    get items_url

    css = style_block(response.body)
    assert_includes css, ACCENT
    assert_equal 1, css.scan(ACCENT).size
    assert_includes css, "--ac6: #b0463a"
    OLD_PALETTE.each { |hex| assert_not_includes css, hex }
  end

  test "the admin layout carries the shared palette plus its own extras" do
    get admin_items_url, headers: admin_headers

    assert_response :success
    css = style_block(response.body)
    assert_includes css, ACCENT
    assert_includes css, "--ac6: #b0463a"
    assert_includes css, "--border-faint"
    OLD_PALETTE.each { |hex| assert_not_includes css, hex }
  end
end
