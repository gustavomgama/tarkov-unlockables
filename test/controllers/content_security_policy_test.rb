require "test_helper"

class ContentSecurityPolicyTest < ActionDispatch::IntegrationTest
  test "the public pages send a content security policy" do
    get root_url

    assert_response :success
    policy = response.headers["Content-Security-Policy"]
    assert_not_nil policy, "expected a Content-Security-Policy header"
    assert_includes policy, "default-src 'self'"
    assert_includes policy, "object-src 'none'"
    assert_includes policy, "base-uri 'self'"
    assert_includes policy, "frame-ancestors 'none'"
  end

  test "the policy allows every external origin the layout loads" do
    get root_url

    policy = response.headers["Content-Security-Policy"]
    # Google Fonts CSS and the Bender woff2 fetched from tarkov.dev.
    assert_includes policy, "https://fonts.googleapis.com"
    assert_includes policy, "https://fonts.gstatic.com"
    assert_includes policy, "https://tarkov.dev"
    # The two footer embeds.
    assert_includes policy, "https://tally.so"
    assert_includes policy, "https://utteranc.es"
  end

  test "the policy applies to admin pages too" do
    get admin_items_url, headers: { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", ENV["ADMIN_PASSWORD"]) }

    assert_response :success
    assert_includes response.headers["Content-Security-Policy"].to_s, "default-src 'self'"
  end
end
