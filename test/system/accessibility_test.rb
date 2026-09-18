require "application_system_test_case"

# Runs axe-core (the npm devDependency) in the browser over the fixture-backed
# pages and fails on any WCAG A/AA violation. The pages are the same ones the
# other system tests drive, so the markup they assert on here is the markup the
# browser actually lays out — axe sees computed styles, not class names, which
# is why it caught the badge and link contrast the source-only tests could not.
#
# fixture-only: system tests must not write to the database (see
# application_system_test_case.rb). Tones that only render for record shapes
# the fixtures do not carry (armor/ammo) are covered by
# test/integration/design_tokens_test.rb instead.
class AccessibilityTest < ApplicationSystemTestCase
  # axe is bundled as a devDependency; the lockfile pins it, so the assertion
  # below runs the same version CI installs.
  AXE_PATH = Rails.root.join("node_modules/axe-core/axe.min.js")
  unless AXE_PATH.exist?
    raise "axe-core is missing — run `npm ci` (this test injects #{AXE_PATH})"
  end
  AXE_JS = AXE_PATH.read.freeze

  # wcag2a/wcag2aa is the level the project targets; 2.1 additions are free.
  AXE_OPTIONS = { runOnly: { type: "tag", values: %w[wcag2a wcag2aa wcag21a wcag21aa] } }.freeze

  # [label, path] pairs. The listings are driven with results, with a filter and
  # with no matches, so the empty states (the least-visited markup on the site)
  # are checked as well as the populated ones.
  PAGES = [
    [ "home", -> { root_path } ],
    [ "items index", -> { items_path } ],
    [ "items filtered", -> { items_path(filters: { caliber: "5.45x39mm" }) } ],
    [ "items search", -> { items_path(q: "Test Item One") } ],
    [ "items empty result", -> { items_path(q: "no-such-item-anywhere") } ],
    [ "items empty filter", -> { items_path(filters: { caliber: "no-such-caliber" }) } ],
    [ "tasks index", -> { tasks_path } ],
    [ "tasks kappa filter", -> { tasks_path(kappa: 1) } ],
    [ "tasks empty trader", -> { tasks_path(trader: "NoSuchTrader") } ],
    [ "task chains", -> { chains_tasks_path } ],
    [ "item show", -> { item_path(items(:one)) } ],
    [ "task show", -> { task_path(tasks(:one)) } ],
    [ "favorites", -> { favorites_path } ],
    # The app renders its own 404 for a missing record; an unmatched *path* would
    # serve Rails' debug page in test and the static public/404.html in
    # production, neither of which is this app's markup.
    [ "record not found", -> { item_path(999_999_999) } ],
    # The static error pages are hand-written HTML that no view test reaches.
    [ "static 404", -> { "/404.html" } ],
    [ "static 500", -> { "/500.html" } ],
    [ "static 400", -> { "/400.html" } ],
    [ "static 422", -> { "/422.html" } ],
    [ "static unsupported browser", -> { "/406-unsupported-browser.html" } ]
  ].freeze

  # The admin area sits behind HTTP Basic; CDP sets the header on the session.
  ADMIN_PAGES = [
    [ "admin dashboard", -> { admin_root_path } ],
    [ "admin items index", -> { admin_items_path } ],
    [ "admin tasks index", -> { admin_tasks_path } ],
    [ "admin item show", -> { admin_item_path(items(:one)) } ],
    [ "admin item new", -> { new_admin_item_path } ],
    # The unlock forms share the `_unlock_form` partial, not the item form.
    [ "admin barter unlock new", -> { new_admin_barter_unlock_path } ],
    [ "admin offer unlock new", -> { new_admin_offer_unlock_path } ]
  ].freeze

  test "the visitor-facing pages have no WCAG A/AA violations" do
    PAGES.each { |label, path| assert_no_violations(instance_exec(&path), label) }
  end

  test "the admin pages have no WCAG A/AA violations" do
    set_basic_auth_header
    ADMIN_PAGES.each { |label, path| assert_no_violations(instance_exec(&path), label) }
  end

  # The error banner only renders after a failed save, so it is a state no GET
  # reaches: submit invalid JSON and check the page the user is left on.
  test "the admin form error state has no WCAG A/AA violations" do
    set_basic_auth_header
    visit new_admin_item_path
    fill_in "item_data", with: "{broken"
    find("input[type=submit]").click

    # Without this the check would pass on the show page if the save started
    # succeeding (the error banner is what is being checked).
    assert_selector "li", text: /must be valid JSON/i
    assert_no_violations(new_admin_item_path, "admin item form errors", navigate: false)
  end

  # The masthead swaps to the `site-menu` disclosure and the filter dropdowns
  # become full-width panels below 640px, so the phone layout is different
  # markup — and the collapsed <details> bodies are hidden from axe until they
  # are opened, which is why the menu and every filter group are expanded here.
  test "the phone layout has no WCAG A/AA violations, menus open" do
    use_viewport(390, 844)

    PAGES.each { |label, path| assert_no_violations(instance_exec(&path), "#{label} (390px)") }

    visit items_path
    find(".site-menu > summary").click
    assert_no_violations(items_path, "items index (390px, menu open)", navigate: false)

    all("details.filter-group > summary").each(&:click)
    assert_no_violations(items_path, "items index (390px, filters open)", navigate: false)
  end

  private

  def assert_no_violations(path, label, navigate: true)
    visit path if navigate
    # The bundle is injected per navigation (the Chrome session outlives a test).
    page.execute_script(AXE_JS)
    result = page.evaluate_async_script(<<~JS)
      const done = arguments[arguments.length - 1];
      axe.run(document, #{AXE_OPTIONS.to_json}, (err, r) => {
        if (err) { done({ error: String(err) }); return; }
        done({ violations: r.violations.map(v => ({
          id: v.id, impact: v.impact, nodes: v.nodes.length, help: v.help,
          targets: v.nodes.slice(0, 3).map(n => n.target.join(" "))
        })) });
      });
    JS

    assert_nil result["error"], "axe failed on #{label}: #{result['error']}"

    violations = (result["violations"] || []).map { |v| "#{v['id']} (#{v['impact']}, #{v['nodes']}×) — #{v['help']}: #{v['targets'].join(' | ')}" }
    assert_empty violations, "WCAG violations on #{label} (#{path}):\n  #{violations.join("\n  ")}"
  end
end
