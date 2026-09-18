require "test_helper"
require "capybara/rails"
require "capybara/minitest"
require "selenium-webdriver"

Capybara.default_driver = :selenium_chrome_headless
Capybara.default_max_wait_time = 10
Capybara.server = :puma, { Silent: true }

Capybara.register_driver :selenium_chrome_headless do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("--headless=new")
  options.add_argument("--no-sandbox")
  options.add_argument("--disable-gpu")
  options.add_argument("--disable-dev-shm-usage")
  options.add_argument("--disable-blink-features=AutomationControlled")
  options.add_preference("download.prompt_for_download", false)
  options.add_preference("browser.cache.disk.enable", false)
  # Browser console capture, read back by SystemTestHelper#console_errors.
  options.add_option("goog:loggingPrefs", { browser: "ALL" })
  # Distros that ship Chromium instead of Google Chrome need the binary named.
  chrome_installed = Dir.glob("{/usr/bin,/opt/google/chrome}/google-chrome*").any?
  if !ENV["CHROME_BIN"] && !chrome_installed && File.executable?("/usr/bin/chromium")
    options.binary = "/usr/bin/chromium"
  end

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

module SystemTestHelper
  extend ActiveSupport::Concern

  included do
    setup :install_console_collector
    # A test that emulates a phone viewport must not leak it into the next one:
    # the CDP override lives on the Chrome session, which outlives a test, so a
    # later test could run at 390px and find the desktop nav hidden.
    teardown :clear_viewport
  end

  # ActionDispatch::SystemTestCase only exposes route helpers for engine tests
  # (via ActionDispatch.test_app); app system tests need them mixed in.
  include Rails.application.routes.url_helpers

  # Selenium 4.48 removed the `manage.logs` API, so console capture happens in
  # the page instead: an init script runs before every document and records
  # window errors, unhandled rejections and console.error calls. Without it the
  # old helper silently returned [] (its `manage.logs?` guard raised
  # NoMethodError into a bare rescue), so every console assertion passed no
  # matter what the page logged.
  # The script is injected once per test (the Chrome session outlives a test),
  # so it guards against running twice in the same document — otherwise the
  # second copy redeclares its const and every page load logs a SyntaxError.
  CONSOLE_COLLECTOR_JS = <<~JS.freeze
    (function () {
      if (window.__consoleCollectorInstalled) return;
      window.__consoleCollectorInstalled = true;
      window.__consoleErrors = [];
      window.addEventListener("error", function (event) {
        window.__consoleErrors.push(event.message || String(event.error));
      });
      window.addEventListener("unhandledrejection", function (event) {
        window.__consoleErrors.push("unhandledrejection: " + String(event.reason));
      });
      var originalConsoleError = console.error;
      console.error = function () {
        window.__consoleErrors.push(Array.prototype.map.call(arguments, String).join(" "));
        originalConsoleError.apply(console, arguments);
      };
    })();
  JS

  def install_console_collector
    page.driver.browser.execute_cdp("Page.addScriptToEvaluateOnNewDocument", source: CONSOLE_COLLECTOR_JS)
  end

  # Resize the viewport through CDP. Window#resize_to fails when Chrome starts
  # maximized ("failed to change window state to 'normal'"), and device
  # metrics also give us real mobile emulation rather than a small window.
  def use_viewport(width, height, mobile: width < 768)
    page.driver.browser.execute_cdp(
      "Emulation.setDeviceMetricsOverride",
      width: width, height: height, deviceScaleFactor: 1, mobile: mobile
    )
  end

  # The admin area is behind HTTP Basic. Chrome refuses credentials embedded in a
  # navigation URL, so the header is set on the session's requests through CDP.
  def set_basic_auth_header(user = "admin", password = ENV.fetch("ADMIN_PASSWORD") { "admin" })
    token = ActionController::HttpAuthentication::Basic.encode_credentials(user, password)
    page.driver.browser.execute_cdp("Network.enable")
    page.driver.browser.execute_cdp("Network.setExtraHTTPHeaders", headers: { Authorization: token })
  end

  def clear_viewport
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  def console_errors
    page.evaluate_script("window.__consoleErrors || []")
  rescue Selenium::WebDriver::Error::JavascriptError
    []
  end

  def assert_no_console_errors(msg = nil)
    errors = console_errors
    assert_empty errors, msg || "Console errors found: #{errors.join(', ')}"
  end
end
