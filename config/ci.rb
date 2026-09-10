# Run using bin/ci
#
# Mirrors the `bundle exec rake ci:all` pipeline (lib/tasks/ci.rake) by
# delegating each phase to its rake task, so there is a single source of
# truth for the commands, thresholds, and perf-tooling checks.

CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Security: Brakeman + bundler-audit", "bundle exec rake ci:security"
  step "Lint: RuboCop", "bundle exec rake ci:lint"
  step "Perf: Fasterer", "bundle exec rake ci:fasterer"
  step "Development: Boot + routes + perf tooling", "bundle exec rake ci:development"
  step "Test: Suite + Bullet/Goldiloader", "bundle exec rake ci:test"
  step "Coverage: 89% line gate", "bundle exec rake ci:coverage"
  step "Audit: Rubycritic ≥ 75", "bundle exec rake ci:audit"

  # Optional: set a green GitHub commit status to unblock PR merge.
  # Requires the `gh` CLI and `gh extension install basecamp/gh-signoff`.
  if success? && system("gh extension list >/dev/null 2>&1") &&
      `gh extension list`.include?("basecamp/gh-signoff")
    step "Signoff: All systems go. Ready for merge and deploy.", "gh signoff"
  elsif !success?
    failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
  end
end
