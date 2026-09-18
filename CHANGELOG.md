# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Accessibility gate: `axe-core` system tests (WCAG 2.0/2.1 A + AA) over 14 public
  and 6 admin page states, on desktop and phone viewports, with the menus open and
  the admin form-error state; plus a WCAG contrast test over the design tokens
- `Permissions-Policy` and `Feature-Policy` headers denying camera, microphone,
  geolocation and the other browser APIs the site does not use
- ESLint + Prettier for the Stimulus controllers, wired as `rake ci:js`
- `active_record_doctor` schema-integrity checks, wired as `rake ci:db_doctor`
  (missing/unindexed foreign keys, mismatched types, extraneous indexes)
- Query budgets and flatness tests for the collection pages (`items#index`,
  `items#show`, `tasks#index`, `tasks#show`, `tasks#chains`, `favorites#index`,
  `items#search`)
- Cross-cutting test suites: link integrity, markup integrity (duplicate ids,
  unbalanced tags, alt text, accessible names), static error pages, Stimulus
  wiring, security headers, and hostile/boundary parameter sweeps
- `Importers::Integrity` aborts a seed whose row counts do not match the source,
  so an incomplete import fails loudly instead of shipping
- `HtmlOnly` controller guard (non-HTML formats get 406) and a failure-based
  admin login throttle
- `erb_lint` plus `rubocop-minitest` / `rubocop-capybara` in the lint gate
- Asset pipeline integration for images (items, traders)
- Bootsnap configuration for production
- Puma configuration with worker/thread tuning
- PostgreSQL connection tuning

### Changed
- Coverage gates: line coverage is 100% and branch coverage is enforced at 95%
  (currently 99.5%); the two previously uncovered branches were reviewed and one
  found to be a misplaced guard that is now tested
- Item and task pages no longer publicly cache state-varying markup
- Database: unique indexes on `favorite_items.item_id` and `tasks.bsg_id`, and
  expression indexes for `items.data->>'caliber'` / `data->>'class'`
  (the filter-option pass went from 349ms to 27ms of SQL)
- Palette: badge and lethality-ramp tones were retuned to pass WCAG AA as text
  and as backgrounds, and text-weight red moved to a `--danger-ink` token
- Puma runs single-mode in test (the cluster-only fork hooks warned on every
  boot) and keeps two workers elsewhere
- Item deletion cascades through barter/craft unlocks and favorites again
- Images moved from `public/images/` to `app/assets/images/` with fingerprinting
- `ApplicationHelper` updated to use asset pipeline
- `HistoricalPurge` no longer deletes image files
- RubyCritic audit scoped to hand-written code (`app config test db/seeds.rb`);
  generated `db/schema.rb` and historical `db/migrate/*` are excluded

### Fixed
- Task importer collapsed every quest with a blank `bsg_id` into one row,
  silently dropping 51 quests and their leads (468 → 519 tasks now import)
- Deleting an item or a task that another row referenced returned 500
- Admin index pages returned 500 for non-numeric `page`/`per_page`, and the
  per-page clamp now matches the public listing
- Typeahead: ArrowUp from nothing focused skipped the last suggestion, and the
  view toggle logged a console error on zero-result pages
- Feedback partial rendered two Tally embeds and an unescaped `&`
- Client-side errors: malformed params now answer 400 and expired CSRF tokens
  422 instead of 500; unknown STI types answer 400
- `permit(:categories)` silently dropped array values, so a category update
  wiped the field
- `loose_search` validates and quotes its column names, which removed the
  `brakeman.ignore` file
- Coverage gate is 89% (`rake ci:coverage`); the line was previously
  documented as 99.8%, which did not match the task

### Removed
- Dead code: `Item`'s `obtain_from` / `unlock_details_for` families,
  `ItemComponent::CardComponent`, `LooseSearchable.build_search_text`,
  `Items::CollapseBaseWeapons`, `TasksHelper#reward_count`, `config/brakeman.ignore`
- `public/images/` directory (990MB) - moved to asset pipeline
- `local_image` helper and `LOCAL_IMAGE_CACHE`
- File deletion logic from `PresetCollapse` and `HistoricalPurge`
- Unused `faraday` and `image_processing` gems (with `mini_magick`,
  `ruby-vips`, `ffi`) and the dead `config/storage.yml`

## [1.2.0] - 2024-08-27

### Added
- Market price backfill via tarkov-market API
- Route-based item purge (removes items without money/barter/craft routes)
- Single-category enforcement with precedence
- Live JSON.tarkov.dev snapshot refresh rake task

### Changed
- Single-category enforcement with precedence (grenades > ammo > gun > ...)
- Item purge now removes items without money/barter/craft routes
- Syncer steps include market sync after crafts

### Removed
- Category protection list (medical, grenades, provisions, containers)

## [1.1.0] - 2024-08-20

### Added
- Category derivation with precedence logic
- Barter sync from json.tarkov.dev
- Craft sync from json.tarkov.dev

### Changed
- Category derivation from single to multi-category (temporarily)

## [1.0.0] - 2024-08-15

### Added
- Initial release
- Item, Task, Trader sync from json.tarkov.dev
- Barter and Craft sync
- Basic web UI for items/tasks/traders