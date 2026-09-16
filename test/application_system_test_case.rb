require "system_test_helper"

# ActionDispatch::SystemTestCase#initialize falls back to driven_by(:selenium)
# when a subclass has not declared a driver, and that default is a *visible*
# Chrome. Visible Chrome needs a display, so on a headless runner every system
# test dies at session creation with "Chrome instance exited" — setting
# Capybara.default_driver is not enough, because Driver#setup overrides
# Capybara.current_driver. Declare the headless driver that
# system_test_helper.rb registers.
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include SystemTestHelper

  driven_by :selenium_chrome_headless

  # Every system test asserts against the pages a visitor sees, which means the
  # seeded rows have to be there. Rows only appeared once a class that declared
  # `fixtures :all` happened to run first, so on a fresh database the outcome
  # depended on the test order — the index rendered its empty state and the
  # view toggle's targets were missing. Load them for the whole base class.
  fixtures :all
end
