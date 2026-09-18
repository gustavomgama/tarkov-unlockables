ENV["RAILS_ENV"] ||= "test"
ENV["ADMIN_PASSWORD"] ||= "admin"

if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start "rails" do
    # Line coverage alone hides untested branches — the else of a ternary, a
    # rescue path, one side of an `||`. Branch coverage surfaces them in the
    # report (and in coverage/coverage.json under total.branches).
    enable_coverage :branch
  end
end

require_relative "../config/environment"
require "rails/test_help"

# Shared test support. The *_test.rb files in this directory are specs that
# the runner discovers on its own; loading them here would run them on every
# filtered invocation too.
Dir[Rails.root.join("test/helpers/**/*.rb")].sort.reject { |f| f.end_with?("_test.rb") }.each { |f| require f }

ActiveSupport::TestCase.include TestFactories

# The admin login throttle uses its own cache store (the app's test cache is a
# null_store, which would silently disable it). Reset it so one test's failed
# logins cannot leak into the next.
ActiveSupport::TestCase.setup { Admin::ApplicationController::FAILED_LOGIN_STORE.clear }
