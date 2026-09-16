# Run using bin/ci
#
# Local mirror of .github/workflows/ci.yml: every check below runs the same
# rake task as its CI job, so the commands and thresholds have a single
# definition (lib/tasks/ci.rake), and CI delegates its docker job back to the
# same rehearsal task. Step to job, in order:
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

CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Security: Brakeman + bundler-audit", "bundle exec rake ci:security"
  step "Lint: RuboCop", "bundle exec rake ci:lint"
  step "Perf: Fasterer", "bundle exec rake ci:fasterer"
  step "Development: Boot + routes + perf tooling", "bundle exec rake ci:development"
  step "Test: Suite + Bullet/Goldiloader", "bundle exec rake ci:test"
  step "Coverage: 89% line gate", "bundle exec rake ci:coverage"
  step "System: Browser tests", "bundle exec rake ci:system"
  step "Audit: Rubycritic ≥ 75", "bundle exec rake ci:audit"
  step "Docker: Build production image", "bundle exec rake ci:docker"
  step "Deploy rehearsal: migrate, boot, poll /up", "bundle exec rake ci:rehearsal"

  # Optional: set a green GitHub commit status to unblock PR merge.
  # Requires the `gh` CLI and `gh extension install basecamp/gh-signoff`.
  if success? && system("gh extension list >/dev/null 2>&1") &&
      `gh extension list`.include?("basecamp/gh-signoff")
    step "Signoff: All systems go. Ready for merge and deploy.", "gh signoff"
  elsif !success?
    failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
  end
end
