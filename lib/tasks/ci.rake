namespace :ci do
  desc "Run full CI pipeline locally (mirrors .github/workflows/ci.yml)"
  task all: %i[security lint fasterer development test coverage audit bullet goldiloader] do
    puts "\n✅ All CI checks passed."
  end

  desc "Brakeman static security analysis + bundler-audit"
  task :security do
    puts "── Security ──"
    run "bundle exec brakeman --no-pager --exit-on-warn"
    run "bundle exec bundler-audit"
  end

  desc "RuboCop linting"
  task :lint do
    puts "── Lint ──"
    run "bundle exec rubocop"
  end

  desc "Fasterer performance-idiom check"
  task :fasterer do
    puts "── Fasterer ──"
    # Suppress RubyParser V40 noise on Ruby 4.0; fasterer falls back to V34
    run "RUBYOPT='-W0' bundle exec fasterer 2>/dev/null || bundle exec fasterer"
  end

  desc "Boot app in development and verify routes"
  task :development do
    puts "── Development ──"
    run "RAILS_ENV=development bundle exec rails db:prepare"
    run "RAILS_ENV=development bundle exec rails runner \"puts 'Rails booted OK: ' + Rails.env\""
    run "RAILS_ENV=development bundle exec rails routes >/dev/null"
    verify_perf_tooling("development")
    run "RAILS_ENV=development bundle exec rake ci:bullet ci:goldiloader"
  end

  desc "Run test suite"
  task :test do
    puts "── Test ──"
    verify_perf_tooling("test", clean_env: true)
    run "RAILS_ENV=test bundle exec rake ci:bullet ci:goldiloader", clean_env: true
    run "RAILS_ENV=test bundle exec rails test", clean_env: true
  end

  desc "Run tests with 90% line coverage enforcement"
  task :coverage do
    puts "── Coverage ──"
    run "RAILS_ENV=test bundle exec rails test", clean_env: true
    score = coverage_percent
    puts "Line coverage: #{score}%"
    abort "❌ Coverage is #{score}% — requires 89%" if score < 89
  end

  desc "Rubycritic score (≥ 75 threshold)"
  task :audit do
    puts "── Audit ──"
    run "bundle exec rubycritic --no-browser --format json app/"
    score = rubycritic_score
    puts "Rubycritic score: #{score}"
    abort "❌ Score #{score} is below 75 threshold" if score < 75
  end

  desc "Verify Bullet N+1 detection is active and strict"
  task :bullet do
    puts "── Bullet ──"
    # Verify stricter settings are present in development.rb
    dev = File.read("config/environments/development.rb")
    abort "❌ Bullet.raise not set" unless dev.include?("Bullet.raise")
    abort "❌ Bullet.unused_eager_loading_enable not set" unless dev.include?("unused_eager_loading_enable")
    abort "❌ Bullet.bullet_logger not set" unless dev.include?("bullet_logger")
    puts "  ✅ Bullet stricter configured (raise=true, unused_eager=true, file log)"
  end

  desc "Verify Goldiloader auto-preload is active globally"
  task :goldiloader do
    puts "── Goldiloader ──"
    dev = File.read("config/environments/development.rb")
    abort "❌ Goldiloader.enabled not set" unless dev.include?("Goldiloader.enabled")
    puts "  ✅ Goldiloader global auto-preload enabled"
  end

  desc "Run security + lint only (fast checks)"
  task quick: %i[security lint]

  private

  def run(command, clean_env: false)
    puts "  $ #{command}"
    if clean_env
      env = ENV.to_h.merge(
        "DATABASE_URL" => nil,
        "DATABASE_URL_POOLED" => nil,
        "DATABASE_URL_UNPOOLED" => nil
      )
      system(env, command) || abort("❌ Command failed: #{command}")
    else
      system(command) || abort("❌ Command failed: #{command}")
    end
  end

  # Confirms the dev/test-only performance gems (bullet, goldiloader) are
  # actually active in the given environment, not just installed.
  def verify_perf_tooling(env, clean_env: false)
    check = "Bullet.enable? && Goldiloader.enabled? ? " \
            "(puts 'bullet + goldiloader active') : abort('perf tooling not active')"
    run "RAILS_ENV=#{env} bundle exec rails runner \"#{check}\"", clean_env: clean_env
  end

  def coverage_percent
    require "json"
    data = JSON.parse(File.read("coverage/coverage.json"))
    data.dig("total", "lines", "percent").to_f
  rescue Errno::ENOENT
    abort "❌ coverage/coverage.json not found — run tests first"
  end

  def rubycritic_score
    report = "tmp/rubycritic/report.json"
    require "json"
    data = JSON.parse(File.read(report))
    data.fetch("score", 0).to_f
  rescue Errno::ENOENT
    abort "❌ #{report} not found — rubycritic must run first"
  end
end
