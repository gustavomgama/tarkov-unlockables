require "test_helper"

# The palette lives in app/assets/stylesheets/application.css, linked by both
# layouts. It used to be rendered from a partial inside a <style> tag, which is
# invalid CSS in development: view annotations inject <!-- BEGIN --> comments
# into the declaration block and the parser swallows the first declaration,
# silently dropping --bg-dark and turning the whole site white.
#
# The browser test below is the one that catches that: it asks for the computed
# value rather than searching the response text. The contrast tests at the
# bottom cover the pairings no browser test reaches on every record shape
# (test/system/accessibility_test.rb runs axe over the fixture-backed pages).
class DesignTokensTest < ActionDispatch::IntegrationTest
  ACCENT = "#c9a84c".freeze
  TOKENS_FILE = Rails.root.join("app/assets/stylesheets/application.css")
  BADGE_MIX = 0.75 # .srcbadge mixes its tone with 25% black.

  # Values .srcbadge is ever given `--tone:` in the views (badge tones plus the
  # lethality ramp, which the armor panel renders as a badge), and the fallback.
  BADGE_TONES = %w[
    --badge-task --badge-barter --badge-craft --badge-hideout --badge-currency
    --badge-offer --trader-prapor --trader-therapist --trader-fence --trader-skier
    --trader-ragman --trader-mechanic --trader-jaeger --trader-lightkeeper
    --trader-peacekeeper --trader-ref --trader-btr-driver --bg-elevated
    --ac1 --ac2 --ac3 --ac4 --ac5 --ac6
  ].freeze

  # Text colours and the surfaces they are painted on (a token can be used on
  # more than one surface, so this is a list of pairs, not a mapping).
  TEXT_PAIRINGS = [
    [ "--ac1", "--bg-surface" ], [ "--ac2", "--bg-surface" ], [ "--ac3", "--bg-surface" ],
    [ "--ac4", "--bg-surface" ], [ "--ac5", "--bg-surface" ], [ "--ac6", "--bg-surface" ],
    [ "--accent", "--bg-surface" ], [ "--accent", "--bg-dark" ],
    [ "--danger-ink", "--bg-dark" ], [ "--danger-ink", "--bg-surface" ],
    [ "--danger-ink", "--bg-elevated" ],
    [ "--success", "--bg-dark" ], [ "--text", "--bg-dark" ], [ "--text-muted", "--bg-surface" ]
  ].freeze

  def assert_tokens_in_stylesheet
    css = TOKENS_FILE.read

    assert_includes css, "--bg-dark: #06080a"
    assert_includes css, "--accent: #{ACCENT}"
    # Print palette must be gated, or it repaints the screen.
    assert_match(/@media print \{\s*:root \{/, css)
  end

  # Both layouts link the stylesheet; neither may declare tokens inline, because
  # development annotations inject comments into the block and the parser
  # swallows the first declaration.
  def assert_palette_linked_not_inline
    assert_select "link[rel=stylesheet][href*=application]"
    inline = response.body[response.body.index("<style>")..response.body.index("</style>")]
    refute_match(/^\s*--[a-z-]+\s*:/, inline,
                     "tokens must not be declared inline: development annotations corrupt the block")
    refute_match(/:root\s*\{/, inline, "no :root block belongs in the layout")
  end

  test "the palette is defined in the linked stylesheet, not inline" do
    get items_url

    assert_response :success
    assert_tokens_in_stylesheet
    assert_palette_linked_not_inline
  end

  test "the admin layout inherits the same palette" do
    password = ENV.fetch("ADMIN_PASSWORD") { "admin" }
    headers = { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", password) }

    get admin_items_url, headers: headers

    assert_response :success
    assert_palette_linked_not_inline
  end

  # WCAG AA is 4.5:1 for the small type these tokens paint (10–14px).
  test "text tokens meet WCAG AA on the surfaces they are painted on" do
    TEXT_PAIRINGS.each do |foreground, background|
      ratio = contrast(tokens.fetch(foreground), tokens.fetch(background))
      assert_operator ratio, :>=, 4.5,
                      "#{foreground} on #{background} measures #{format('%.2f', ratio)}:1 (needs 4.5:1)"
    end
  end

  test "badge tones meet WCAG AA against --text-bright after the .srcbadge mix" do
    bright = tokens.fetch("--text-bright")

    BADGE_TONES.each do |tone|
      background = mix_with_black(tokens.fetch(tone), BADGE_MIX)
      ratio = contrast(bright, background)
      assert_operator ratio, :>=, 4.5,
                      "#{tone} as a .srcbadge background measures #{format('%.2f', ratio)}:1 " \
                      "against --text-bright (needs 4.5:1)"
    end
  end

  test "the solid danger red keeps bright text legible" do
    # --danger stays the background for the Kappa chips and the delete button;
    # text uses --danger-ink instead.
    ratio = contrast(tokens.fetch("--text-bright"), tokens.fetch("--danger"))
    assert_operator ratio, :>=, 4.5,
                    "--danger with --text-bright measures #{format('%.2f', ratio)}:1 (needs 4.5:1)"
  end

  private

  def tokens
    @tokens ||= TOKENS_FILE.read[/:root \{(.*?)\}/m, 1]
                      .scan(/(--[\w-]+):\s*(#[0-9a-fA-F]{6})/)
                      .to_h
  end

  def mix_with_black(hex, factor)
    rgb = channels(hex).map { |c| (c * factor).round }
    "##{rgb.map { |c| format('%02x', c) }.join}"
  end

  # WCAG 2.x relative luminance: each sRGB channel is linearised, then the
  # three are weighted.
  LUMINANCE_WEIGHTS = [ 0.2126, 0.7152, 0.0722 ].freeze

  def luminance(hex)
    channels(hex).zip(LUMINANCE_WEIGHTS).sum do |channel, weight|
      linear = channel / 255.0
      weight * (linear <= 0.03928 ? linear / 12.92 : ((linear + 0.055) / 1.055)**2.4)
    end
  end

  def contrast(a, b)
    light, dark = [ luminance(a), luminance(b) ].sort.reverse
    (light + 0.05) / (dark + 0.05)
  end

  def channels(hex)
    hex.delete("#").scan(/../).map { |pair| pair.to_i(16) }
  end
end
