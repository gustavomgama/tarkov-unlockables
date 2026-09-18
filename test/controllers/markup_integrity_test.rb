require "test_helper"

# Frontend structure checks that assert_select cannot see: Nokogiri silently
# repairs broken markup and happily matches duplicated ids, so unbalanced tags
# and repeated ids ship unnoticed (a duplicated feedback block already did).
class MarkupIntegrityTest < ActionDispatch::IntegrationTest
  include ItemsTestHelpers
  include AdminRequestAuth

  setup do
    @item = create_item("Markup Item", klass: Item::Weapon, short_name: "MI",
                        data: { "caliber" => "5.45x39mm", "damage" => 50, "ergonomics" => 50 })
    @task = create_task("Markup Task", "markup-task", given_by: "Prapor")
  end

  teardown do
    @item&.destroy
    @task&.destroy
  end

  PAGES = {
    "items index" => -> { items_path },
    "items empty search" => -> { items_path(q: "no-such-item-anywhere") },
    "items empty filter" => -> { items_path(filters: { caliber: "no-such-caliber" }) },
    "item show" => -> { item_path(@item) },
    "tasks index" => -> { tasks_path },
    "tasks empty trader" => -> { tasks_path(trader: "NoSuchTrader") },
    "task chains" => -> { chains_tasks_path },
    "task show" => -> { task_path(@task) },
    "favorites" => -> { favorites_path },
    "admin dashboard" => -> { admin_root_path },
    "admin items index" => -> { admin_items_path },
    "admin item show" => -> { admin_item_path(@item) },
    "admin item form" => -> { new_admin_item_path },
    "admin item edit" => -> { edit_admin_item_path(@item) },
    "admin task form" => -> { new_admin_task_path },
    # Hand-written static pages: no view renders them, so only these checks see
    # their markup.
    "static 400" => -> { "/400.html" },
    "static 404" => -> { "/404.html" },
    "static 422" => -> { "/422.html" },
    "static 500" => -> { "/500.html" },
    "static unsupported browser" => -> { "/406-unsupported-browser.html" }
  }.freeze

  def each_page
    PAGES.each do |name, path|
      get_auth instance_exec(&path)
      assert_response :success, name

      yield name, Nokogiri::HTML(response.body)
    end
  end

  test "no page repeats an element id" do
    each_page do |name, doc|
      ids = doc.css("[id]").map { |node| node["id"] }.reject(&:blank?)
      duplicates = ids.tally.select { |_, count| count > 1 }.keys

      assert_empty duplicates, "#{name} repeats id(s): #{duplicates.inspect}"
    end
  end

  # Nokogiri's HTML5 mode is tolerant by spec; the strict HTML4 parser reports a
  # stray closing tag and an unescaped "&". It also calls every HTML5 element
  # invalid, so those messages are dropped and only the structural ones asserted.
  IGNORED_MARKUP_ERRORS = /Tag \w+ invalid/

  test "no page has unbalanced tags or unescaped ampersands" do
    each_page do |name, _|
      messages = Nokogiri::HTML(response.body).errors
                         .map(&:message)
                         .reject { |message| message.match?(IGNORED_MARKUP_ERRORS) }
      next if messages.empty?

      line_number = messages.first[/\A(\d+)/, 1].to_i
      excerpt = response.body.lines[line_number - 1].to_s.strip[0, 300]
      flunk "#{name} has malformed markup: #{messages.inspect}\non line #{line_number}: #{excerpt}"
    end
  end

  # The layout's accessibility contract: a skip link that actually reaches the
  # main landmark, a language on the document, and the live region the typeahead
  # announces into. None of these were asserted (axe checks the *presence* of a
  # lang attribute, not its value, and does not follow the skip link).
  test "the layout wires the skip link, the main landmark and the live region" do
    each_page do |name, doc|
      # The static error pages are standalone documents with no navigation to
      # skip, so they only need the language.
      next if name.start_with?("static ")

      skip = doc.at_css("a.skip-link")
      assert skip, "#{name} has no skip link"
      target = skip["href"].to_s.delete_prefix("#")
      assert doc.at_css("##{target}"), "#{name}: skip link points at ##{target}, which does not exist"

      assert_equal "en", doc.at_css("html")["lang"], "#{name} declares the wrong document language"
    end

    get_auth items_path
    doc = Nokogiri::HTML(response.body)
    assert_equal "polite", doc.at_css("#search-results")["aria-live"],
                 "the typeahead results must be a polite live region"
    assert doc.at_css("[role=region][aria-label]"), "the table view needs a labelled region"
  end

  test "every image carries an alt attribute" do
    each_page do |name, doc|
      missing = doc.css("img:not([alt])").map { |node| node["src"] }

      assert_empty missing, "#{name} has img without alt: #{missing.inspect}"
    end
  end

  # A control that only reads as an icon needs a name for screen readers.
  test "every button and link has an accessible name" do
    each_page do |name, doc|
      nameless = doc.css("a, button").reject do |node|
        node.text.present? || node["aria-label"].present? || node["title"].present? ||
          node.at_css("img[alt]:not([alt=''])")
      end

      assert_empty nameless.map { |node| node.to_html[0, 80] },
                   "#{name} has controls with no accessible name"
    end
  end
end
