source "https://rubygems.org"

gem "rails", "~> 8.1.3"
gem "turbo-rails"
gem "stimulus-rails"
gem "importmap-rails"
gem "propshaft"
gem "pg", "~> 1.5"
gem "ransack"
gem "puma", ">= 5.0"
gem "thruster"
gem "tzinfo-data", platforms: %i[ windows jruby ]
gem "bootsnap", require: false
gem "annotaterb", "~> 4.24"
gem "dotenv", require: false

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "bundler-audit", require: false
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
  gem "rubocop-performance", require: false
  gem "rubycritic", require: false
  gem "bullet"
  gem "goldiloader"
  gem "active_record_doctor", "~> 2.0"
end

group :development do
  gem "web-console"
  gem "fasterer", require: false
  gem "solargraph", "~> 0.60.1"
end

group :test do
  gem "simplecov", require: false
  gem "selenium-webdriver"
  gem "capybara"
end

gem "tailwindcss-rails", "~> 4.6"
gem "view_component", "~> 4.15"

gem "erb_lint", "~> 0.9.0", group: :development

gem "rubocop-minitest", "~> 0.40.0", group: :development
gem "rubocop-capybara", "~> 3.0", group: :development

gem "stackprof", "~> 0.2.28", group: :development
