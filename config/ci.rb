# Run using bin/ci
#
# Local mirror of .github/workflows/ci.yml: every check below runs the same
# rake task as its CI job, so the commands and thresholds have a single
# definition (lib/tasks/ci.rake), and CI's docker job delegates its rehearsal
# back to the same task. Step to job:
#
#   ci.yml job     step
#   ───────────    ─────────────────────────────────────────
#   security       Security: Brakeman + bundler-audit
#   lint           Lint: RuboCop
#   lint           Perf: Fasterer
#   development    Development: Boot + routes + perf tooling
#   test           Test: Suite + Bullet/Goldiloader
#   coverage       Coverage: 89% line gate
#   system         System: Browser tests
#   audit          Audit: Rubycritic ≥ 75
#   docker         Docker: Build production image
#   docker         Deploy rehearsal: migrate, boot, poll /up
#
# Two steps have no CI job: Setup primes a freshly cloned checkout, and
# Signoff is the optional commit status CI uses to allow a merge.
#
# Setup runs alone, then the sequences below run concurrently the way the CI
# jobs do. A sequence is a list of steps that must stay in order because they
# share a resource:
#
#   static       reads the source tree only
#   development  uses the development database
#   test-db      test, coverage and system all use the test database
#   audit        reads app/, writes tmp/rubycritic
#   docker       builds the image, then owns port 3001 and its containers
#
# Each step's output goes to tmp/ci/<step>.log so concurrent steps do not
# interleave; a failing step's log tail is printed instead.

require "fileutils"

CI.run do
  step "Setup", "bin/setup --skip-server"

  sequences = [
    [ [ "Security: Brakeman + bundler-audit", "bundle exec rake ci:security" ],
      [ "Lint: RuboCop", "bundle exec rake ci:lint" ],
      [ "Perf: Fasterer", "bundle exec rake ci:fasterer" ] ],
    [ [ "Development: Boot + routes + perf tooling", "bundle exec rake ci:development" ] ],
    [ [ "Test: Suite + Bullet/Goldiloader", "bundle exec rake ci:test" ],
      [ "Coverage: 89% line gate", "bundle exec rake ci:coverage" ],
      [ "System: Browser tests", "bundle exec rake ci:system" ] ],
    [ [ "Audit: Rubycritic ≥ 75", "bundle exec rake ci:audit" ] ],
    [ [ "Docker: Build production image", "bundle exec rake ci:docker" ],
      [ "Deploy rehearsal: migrate, boot, poll /up", "bundle exec rake ci:rehearsal" ] ]
  ]

  log_dir = File.expand_path("../tmp/ci", __dir__)
  FileUtils.mkdir_p(log_dir)
  reporting = Mutex.new

  # Runs one step and returns whether it passed. The tail of the log is the
  # only thing worth showing for a failure, so concurrent logs stay readable.
  run_step = lambda do |title, command|
    log = File.join(log_dir, "#{title.downcase.gsub(/[^a-z0-9]+/, "-")}.log")
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    passed = File.open(log, "w") { |io| system(command, out: io, err: io) }
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

    reporting.synchronize do
      echo format("%s %s (%.1fs)", passed ? "✅" : "❌", title, elapsed),
           type: passed ? :success : :error
      unless passed
        puts "   failed — last 40 lines of #{log}:"
        puts File.readlines(log).last(40).map { |line| "   #{line}" }
      end
    end
    passed
  end

  sequences.each { |sequence| sequence.each { |title, _| echo "▶ #{title}", type: :title } }

  runs = sequences.map do |sequence|
    Thread.new { sequence.map { |title, command| run_step.call(title, command) } }
  end

  results.concat(runs.flat_map(&:value))

  # Optional: set a green GitHub commit status to unblock PR merge.
  # Requires the `gh` CLI and `gh extension install basecamp/gh-signoff`.
  if success? && system("gh extension list >/dev/null 2>&1") &&
      `gh extension list`.include?("basecamp/gh-signoff")
    step "Signoff: All systems go. Ready for merge and deploy.", "gh signoff"
  elsif !success?
    failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
  end
end
