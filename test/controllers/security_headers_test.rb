require "test_helper"

# Locks the response-hardening posture on both surfaces. These are Rails'
# defaults plus the Permissions-Policy pair (Rails 8 emits the deprecated
# Feature-Policy from `config.permissions_policy`; the modern
# Permissions-Policy is set in config/application.rb). A change to any value
# should be deliberate, so the values are asserted rather than "present".
class SecurityHeadersTest < ActionDispatch::IntegrationTest
  # The APIs the site never uses, denied on every response.
  DENIED_DIRECTIVES = %w[
    camera display-capture geolocation gyroscope microphone midi payment usb
  ].freeze

  DEFAULT_HEADERS = {
    "X-Frame-Options" => "SAMEORIGIN",
    "X-Content-Type-Options" => "nosniff",
    "X-Permitted-Cross-Domain-Policies" => "none",
    "Referrer-Policy" => "strict-origin-when-cross-origin"
  }.freeze

  test "public and admin pages send the hardened headers" do
    admin = { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", ENV.fetch("ADMIN_PASSWORD") { "admin" }) }

    [ [ root_url, {} ], [ admin_items_url, admin ] ].each do |url, headers|
      get url, headers: headers

      assert_response :success
      DEFAULT_HEADERS.each { |name, value| assert_equal value, response.headers[name], "#{name} on #{url}" }
      DENIED_DIRECTIVES.each do |directive|
        assert_includes response.headers["Permissions-Policy"].to_s, "#{directive}=()", "Permissions-Policy on #{url}"
        # Legacy spelling, from config.permissions_policy, for older parsers.
        assert_includes response.headers["Feature-Policy"].to_s, "#{directive} 'none'", "Feature-Policy on #{url}"
      end
    end
  end

  # HSTS and the secure-cookie flags come from `config.force_ssl`, which only
  # applies in production — so the production environment file is what is
  # asserted here (the setting cannot be observed from the test environment).
  test "production forces SSL" do
    production = Rails.root.join("config/environments/production.rb").read

    assert_match(/^\s*config\.force_ssl = true/, production)
    assert_match(/^\s*config\.assume_ssl = true/, production)
  end
end
