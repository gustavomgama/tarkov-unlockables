require_relative "boot"

require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"
# Unused frameworks stay unloaded (no mailers, jobs, cable, storage,
# mailbox, or text in this app): faster boot, less memory, ~27 fewer
# dead routes from rails/all.
require "dotenv" unless Rails.env.test?

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module TakovDb
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # The site needs none of these APIs, so they are denied outright instead of
    # relying on the browser default. Anything not listed stays at its default
    # (not restricted by this header) — this is a deny list, not an allow list.
    config.permissions_policy do |policy|
      policy.camera :none
      policy.display_capture :none
      policy.geolocation :none
      policy.gyroscope :none
      policy.microphone :none
      policy.midi :none
      policy.payment :none
      policy.usb :none
    end

    # Rails 8's `config.permissions_policy` still emits the deprecated
    # `Feature-Policy` header; browsers read `Permissions-Policy`. Send the
    # modern header too, with the same denials, so neither parser is left out.
    config.action_dispatch.default_headers["Permissions-Policy"] = %w[
      camera display-capture geolocation gyroscope microphone midi payment usb
    ].map { |directive| "#{directive}=()" }.join(", ")
  end
end
