# Contributing to Tarkov Unlockables

Thank you for your interest in contributing! This project welcomes contributions from the community.

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally
3. **Create a branch** for your changes
4. **Make your changes**
5. **Run the test suite** to ensure nothing breaks
6. **Submit a pull request**

## Development Setup

```bash
# Clone the repo
git clone https://github.com/your-username/tarkov-unlockables.git
cd tarkov-unlockables

# Install dependencies
bundle install

# Set up the database
bin/rails db:prepare

# Run the test suite
bin/rails test
```

## Code Style

This project uses:

- **RuboCop** for Ruby linting (Omakase + performance/minitest/capybara, config in `.rubocop.yml`)
- **erb_lint** for ERB template linting (config in `.erb_lint.yml`)
- **ESLint + Prettier** for the Stimulus controllers (config in `eslint.config.mjs` and `.prettierrc.json`)
- **axe-core** for WCAG A/AA checks on the rendered pages (`test/system/accessibility_test.rb`)
- **Brakeman** for security scanning
- **Bundler-audit** for gem vulnerability checks
- **Fasterer** for performance idioms
- **active_record_doctor** for schema integrity — missing foreign keys/indexes, mismatched column types (`ci:db_doctor`; exceptions with reasons in `.active_record_doctor.rb`)
- **RubyCritic** for code quality (score ≥ 75 required)
- **unittest** for the Python wiki parser (`lib/wiki_parser`, needs `requirements.txt`)

Run the checks through the shared rake tasks so local runs match CI exactly:

```bash
bundle exec rake ci:quick   # security + lint (rubocop + erb_lint + eslint/prettier)
bundle exec rake ci:js      # JS only: ESLint + Prettier
bundle exec rake ci:db_doctor  # schema integrity (needs the test database)
bundle exec rake ci:all     # full pipeline
```

The JS checks and the accessibility system test use the devDependencies pinned
in `package-lock.json`, so run `npm ci` once after cloning (or when the lockfile
changes).

`ci:audit` scores hand-written code (`app config test db/seeds.rb`);
`db/schema.rb` is generated and `db/migrate/*` are historical snapshots, so
they are deliberately excluded.

## Testing

```bash
# Run all tests
bin/rails test

# Run with coverage
COVERAGE=true bin/rails test

# Run a specific test
bin/rails test test/path/to/test_file.rb
```

**Coverage requirement**: 89% line coverage minimum (`rake ci:coverage`); the
suite currently sits at 100%.

## Pull Request Process

1. **Keep PRs focused** - one feature/fix per PR
2. **Write clear commit messages** - follow [Conventional Commits](https://www.conventionalcommits.org/)
3. **Update tests** - add tests for new features, update existing tests for bug fixes
4. **Update documentation** - README, CHANGELOG, comments as needed
5. **Ensure CI passes** - all checks must pass before merge

## Commit Message Format

```
type(scope): brief description

[optional body]

[optional footer]
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `perf`, `ci`

Examples:
```
feat(sync): add market price backfill for food items
docs(readme): add deploy instructions for Render
```

## Code Review

All PRs require at least one review. Reviewers will check:
- Code correctness and style
- Test coverage
- Security implications
- Performance impact
- Documentation updates

## Reporting Issues

- **Bugs**: Use the bug report template
- **Features**: Use the feature request template
- **Security**: See SECURITY.md

## Questions?

Open a discussion or issue for any questions about contributing.