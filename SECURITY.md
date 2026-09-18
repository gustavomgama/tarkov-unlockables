# Security Policy

## Reporting a vulnerability

Please report security issues **privately** — do not open a public issue.

- Preferred: GitHub's private vulnerability reporting — go to the repository's
  **Security** tab and choose **Report a vulnerability**.
- If that is unavailable, contact the maintainer directly through their GitHub
  profile.

Include the affected version or commit, a description of the issue, and a
minimal reproduction if you have one. You can expect an initial response
within a few days.

## Scope

This is a read-mostly reference app. The pieces that matter most are:

- the admin panel (HTTP Basic auth; `ADMIN_PASSWORD` must be set — it fails
  closed if unset, see `config/initializers/admin_password_check.rb`),
- the importers that read `offlinedata/` and write the database,
- stored user-controlled strings rendered as links (the wiki link normalizer
  drops `javascript:`/`data:` URLs).

Automated checks already run in CI: Brakeman, bundler-audit, RuboCop, and
CodeQL (Ruby, JavaScript/TypeScript, Python, Actions).
