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
  # Servers without Google Chrome ship Chromium under a different name.
  options.binary = "/usr/bin/chromium" if File.executable?("/usr/bin/chromium") && !ENV["CHROME_BIN"]

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

module SystemTestHelper
  # ActionDispatch::SystemTestCase only exposes route helpers for engine tests
  # (via ActionDispatch.test_app); app system tests need them mixed in.
  include Rails.application.routes.url_helpers

  def capture_console_messages
    @console_messages = []
    return [] unless page.driver.browser.manage.logs?
    page.driver.browser.manage.logs.get(:browser).each do |log|
      @console_messages << {
        level: log.level,
        message: log.message,
        timestamp: log.timestamp
      }
    end
    @console_messages
  rescue => e
    []
  end

  def console_errors
    capture_console_messages.select { |m| m[:level] == "SEVERE" }
  end

  def assert_no_console_errors(msg = nil)
    errors = console_errors
    assert errors.empty?, msg || "Console errors found: #{errors.map { |e| e[:message] }.join(', ')}"
  end
end
