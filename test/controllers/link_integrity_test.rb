require "test_helper"

# Walks the links the pages actually render and requests them. Route helpers are
# checked at boot, but a link can still point at a path that no longer resolves
# (a renamed route, a hard-coded href, a deleted static file), and nothing else
# in the suite would notice.
class LinkIntegrityTest < ActionDispatch::IntegrationTest
  fixtures :all

  # Pages that together link to every section of the site.
  PUBLIC_PAGES = [
    -> { root_url },
    -> { items_url },
    -> { items_url(q: "Test") },
    -> { tasks_url },
    -> { chains_tasks_url },
    -> { favorites_url },
    -> { item_url(items(:one)) },
    -> { task_url(tasks(:one)) }
  ].freeze

  ADMIN_PAGES = [
    -> { admin_root_url },
    -> { admin_items_url },
    -> { admin_tasks_url },
    -> { admin_item_url(items(:one)) }
  ].freeze

  # Static assets are served by Propshaft outside the controller tests, so they
  # are skipped. The admin pages are walked with credentials and skipped from
  # the public pass.
  ASSET_AND_INFRA = %r{\A/(assets|rails|up)\b|\.(png|jpe?g|svg|ico|css|js|woff2?)\z}
  ADMIN = %r{\A/admin\b}

  test "every internal link rendered on the pages resolves" do
    [ [ PUBLIC_PAGES, ADMIN, {} ], [ ADMIN_PAGES, nil, admin_headers ] ].each do |pages, skip, headers|
      hrefs = collect_hrefs(pages, skip: skip, headers: headers)

      assert_operator hrefs.size, :>=, 5, "expected the pages to link to each other"
      hrefs.each { |href| assert_resolves(href, headers) }
    end
  end

  private

  def admin_headers
    password = ENV.fetch("ADMIN_PASSWORD") { "admin" }
    { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", password) }
  end

  def collect_hrefs(pages, skip:, headers:)
    hrefs = Set.new

    pages.each do |page|
      get instance_exec(&page), headers: headers
      assert_response :success

      Nokogiri::HTML(response.body).css("a[href]").each do |anchor|
        href = anchor["href"]
        next unless href&.start_with?("/")
        next if href.start_with?("//") || href.match?(ASSET_AND_INFRA) || (skip && href.match?(skip))

        hrefs << href.split("#").first
      end
    end

    hrefs.to_a.sort
  end

  def assert_resolves(href, headers)
    get href, headers: headers

    assert_includes 200..399, response.status,
                    "GET #{href} returned #{response.status} (linked from the rendered pages)"
  end
end
