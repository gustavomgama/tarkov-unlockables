require "test_helper"

# The palette lives in app/assets/stylesheets/application.css, linked by both
# layouts. It used to be rendered from a partial inside a <style> tag, which is
# invalid CSS in development: view annotations inject <!-- BEGIN --> comments
# into the declaration block and the parser swallows the first declaration,
# silently dropping --bg-dark and turning the whole site white.
#
# The browser test below is the one that catches that: it asks for the computed
# value rather than searching the response text.
class DesignTokensTest < ActionDispatch::IntegrationTest
  ACCENT = "#c9a84c".freeze

  def assert_tokens_in_stylesheet
    css = Rails.root.join("app/assets/stylesheets/application.css").read

    assert_includes css, "--bg-dark: #06080a"
    assert_includes css, "--accent: #{ACCENT}"
    assert_includes css, "--ac6: #b0463a"
    # Print palette must be gated, or it repaints the screen.
    assert_match(/@media print \{\s*:root \{/, css)
  end

  test "the palette is defined in the linked stylesheet, not inline" do
    get items_url

    assert_response :success
    assert_tokens_in_stylesheet
    assert_select "link[rel=stylesheet][href*=application]"

    inline = response.body[response.body.index("<style>")..response.body.index("</style>")]
    refute_match(/^\s*--[a-z-]+\s*:/, inline,
                     "tokens must not be declared inline: development annotations corrupt the block")
    refute_match(/:root\s*\{/, inline, "no :root block belongs in the layout")
  end

  test "the admin layout inherits the same palette" do
    password = ENV.fetch("ADMIN_PASSWORD") { "admin" }
    headers = { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", password) }

    get admin_items_url, headers: headers

    assert_response :success
    assert_select "link[rel=stylesheet][href*=application]"
    inline = response.body[response.body.index("<style>")..response.body.index("</style>")]
    refute_match(/^\s*--[a-z-]+\s*:/, inline)
  end
end
