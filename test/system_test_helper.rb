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

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

module SystemTestHelper
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

  def console_warnings
    capture_console_messages.select { |m| m[:level] == "WARNING" }
  end

  def assert_no_console_errors(msg = nil)
    errors = console_errors
    assert errors.empty?, msg || "Console errors found: #{errors.map { |e| e[:message] }.join(', ')}"
  end

  def enable_network_tracking
    @network_events = []
    page.driver.browser.execute_cdp("Network.enable")
    page.driver.browser.on("Network.requestWillBeSent") do |params|
      @network_events << {
        type: "request",
        timestamp: params["timestamp"],
        request_id: params["requestId"],
        url: params["request"]["url"],
        method: params["request"]["method"],
        resource_type: params["type"]
      }
    end
    page.driver.browser.on("Network.responseReceived") do |params|
      @network_events << {
        type: "response",
        timestamp: params["timestamp"],
        request_id: params["requestId"],
        url: params["response"]["url"],
        status: params["response"]["status"],
        mime_type: params["response"]["mimeType"]
      }
    end
    page.driver.browser.on("Network.loadingFailed") do |params|
      @network_events << {
        type: "failure",
        timestamp: params["timestamp"],
        request_id: params["requestId"],
        url: params["request"]["url"],
        error_text: params["errorText"],
        canceled: params["canceled"]
      }
    end
  rescue => e
    @network_events ||= []
  end

  def disable_network_tracking
    page.driver.browser.execute_cdp("Network.disable")
  rescue => e
    # Ignore errors when disabling
  end

  def track_requests
    enable_network_tracking
    yield
  ensure
    disable_network_tracking
  end

  def network_requests
    @network_events.select { |e| e[:type] == "request" }
  end

  def network_responses
    @network_events.select { |e| e[:type] == "response" }
  end

  def network_failures
    @network_events.select { |e| e[:type] == "failure" }
  end

  def find_request(url_pattern:)
    network_requests.find { |e| e[:url].match?(url_pattern) }
  end

  def find_response(url_pattern:)
    network_responses.find { |e| e[:url].match?(url_pattern) }
  end

  def requests_to(url_pattern)
    network_requests.select { |e| e[:url].match?(url_pattern) }
  end

  def responses_from(url_pattern)
    network_responses.select { |e| e[:url].match?(url_pattern) }
  end

  def assert_request_made(url_pattern:, method: nil, times: nil)
    requests = requests_to(url_pattern)
    requests = requests.select { |r| r[:method] == method } if method

    assert requests.any?, "Expected request to #{url_pattern}#{method ? " with method #{method}" : ""} but none found. Requests made: #{network_requests.map { |r| r[:url] }.join(', ')}"

    if times
      assert_equal times, requests.size, "Expected #{times} requests to #{url_pattern} but found #{requests.size}"
    end
  end

  def assert_response_status(url_pattern:, status:)
    response = find_response(url_pattern)
    assert response, "Expected response from #{url_pattern} but none found"
    assert_equal status, response[:status], "Expected status #{status} for #{url_pattern} but got #{response[:status]}"
  end

  def get_response_body(url_pattern:)
    response = find_response(url_pattern)
    return nil unless response

    request = network_requests.find { |r| r[:request_id] == response[:request_id] }
    return nil unless request

    page.driver.browser.execute_cdp("Network.getResponseBody", requestId: response[:request_id])["body"]
  end
end
