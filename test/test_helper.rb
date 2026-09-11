ENV["RAILS_ENV"] ||= "test"
ENV["ADMIN_PASSWORD"] ||= "admin"

if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start "rails"
end

require_relative "../config/environment"
require "rails/test_help"

Dir[Rails.root.join("test/helpers/**/*.rb")].sort.each { |f| require f }
