# Implementation Plan: Tarkov Unlockables Access System

**Branch**: `001-tarkov-unlockables-access` | **Date**: 2026-09-11 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/001-tarkov-unlockables-access/spec.md`

**Note**: Clarification from `/speckit.clarify` fully resolved — presentation-layer focus confirmed (no functional gun/item mechanics), human-readable data confirmed, DB record independence confirmed, show-page duplicate rules clarified (no duplicate info on show pages).

## Summary

Build a full-stack Rails 8.1.3 reference/access tool for Escape from Tarkov task-gated unlockables. Focus: presentation-layer visibility (not item mechanics), human-readable data, independent DB records, zero-cost, maximum speed. Uses Hotwire/Turbo/Stimulus, SolidCache/SolidQueue/SolidCable, TailwindCSS, Propshaft, PostgreSQL.

## Technical Context

**Language/Version**: Ruby 4.0.6 / Rails 8.1.3

**Primary Dependencies**: Rails 8.1.3, PostgreSQL, Hotwire (Turbo + Stimulus), SolidCache, SolidQueue, SolidCable, TailwindCSS, Propshaft, mwparserfromhell (for offlinedata parsing)

**Storage**: PostgreSQL (existing project DB)

**Testing**: Minitest (Rails default), system/integration tests for full-stack flows

**Target Platform**: Web application (full stack)

**Project Type**: web-service / full-stack web app

**Performance Goals**: Fastest possible response; profiling mandatory for non-trivial logic; SolidCache for hot data; SolidQueue for background parsing

**Constraints**: Zero dollar budget ($0); all open-source; offlinedata parseable; DB record independence (no cascading deletes); presentation-layer only (no functional gun/item mechanics)

**Scale/Scope**: Reference/access tool for task-gated unlockables; not a game mechanic modifier; mobile/in-game overlay out of scope

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Full Stack | PASS | Rails full stack with Hotwire |
| II. Offlinedata Parseable | PASS | `mwparserfromhell` for wikitext; parseable data source |
| III. Zero Dollar Budget | PASS | All dependencies open-source/free |
| IV. Maximum Performance | PASS | SolidCache, Propshaft, profiling required |
| V. Minimal Complexity | PASS | No speculative abstractions; lazy-correct default |

No violations. Proceed.

## Project Structure

### Source Code (repository root — existing Rails app)

```text
app/
├── controllers/
│   └── unlockables_controller.rb
├── models/
│   ├── task.rb
│   ├── unlockable_item.rb
│   ├── buyable_item.rb
│   ├── craftable_item.rb
│   └── barterable_item.rb
├── views/
│   └── unlockables/
│       ├── index.html.erb
│       ├── show.html.erb
│       └── _item.html.erb
├── javascript/
│   └── controllers/
│       └── unlockable_controller.js
lib/
├── parsers/
│   └── offlinedata_parser.rb
config/
├── routes.rb (updated)
db/
├── migrate/
│   └── [timestamp]_create_unlockables.rb
```

**Structure Decision**: Existing Rails app extended with new controllers, models, views, and a parser library. No new frontend framework — Hotwire/Turbo/Stimulus native.

## Skills & MCPs Utilized

Installed skills (from `~/.opencode/skills/` and `skills-lock.json`):
- `ruby-version-manager` — Ruby version detection before any command
- `rubyn-rspec` — RSpec patterns (if needed for TDD)
- `executing-plans` — execution of multi-step plans
- `verification-before-completion` — verify before claiming done
- `test-driven-development` — TDD workflow enforcement
- `using-git-worktrees` — isolated workspace for feature work
- `subagent-driven-development` — parallel agent dispatch
- `using-superpowers` — skill invocation protocol
- `finishing-a-development-branch` — branch integration
- `dispatching-parallel-agents` — parallel task execution
- `writing-plans` — implementation plan creation
- `receiving-code-review` — rigorous review of feedback
- `writing-skills` — skill creation/editing
- `requesting-code-review` — review request protocol
- `systematic-debugging` — structured bug fixing
- `brainstorming` — design exploration
- `the-pragmatic-programmer` — pragmatic coding principles
- `refactoring-guru` — refactoring patterns
- `designing-data-intensive-applications` — data system design
- `implementing-domain-driven-design` — DDD patterns
- `brand` — brand consistency
- `working-effectively-with-legacy-code` — legacy code practices
- `design` — comprehensive design (logo, CIP, banners, icons, slides)
- `banner-design` — banner creation
- `design-system` — token architecture
- `refactoring` — refactoring moves
- `slides` — strategic presentations
- `ruby-resource-map` — Ruby documentation sources
- `ponytail-help` — ponytail reference
- `rubyn-self_test` — self-test patterns
- `ponytail-audit` — over-engineering audit
- `ruby-test-frameworks` — minitest/test-unit naming
- `rubyn-gems` — gem guidance
- `domain-driven-design-distilled` — DDD distilled
- `ponytail-debt` — debt tracking
- `task-observer` — observation logging
- `a-philosophy-of-software-design` — design philosophy
- `rubyn-rails` — Rails patterns
- `rubyn-code_quality` — code quality standards
- `ruby-version-manager` — version manager detection
- `customize-opencode` — opencode config
- `cursor-api-key-management` — API key config
- `frontend-design` — anti-slop UI direction
- `playwright-testing` — E2E testing
- `advanced-frontend-uiux` — elite visual effects
- `rubyn-minitest` — minitest patterns
- `patterns-of-enterprise-application-architecture` — enterprise patterns
- `release-it` — release practices
- `ui-ux-pro-max` — design intelligence database
- `rubyn-design_patterns` — Ruby design patterns
- `rubyn-solid` — SOLID principles
- `rubyn-ruby_project` — Ruby project conventions
- `domain-driven-design` — DDD principles
- `rubyn-sinatra` — Sinatra patterns
- `nuke-on-rails` — Rails audit
- `ponytail-review` — over-engineering review
- `rubyn-refactoring` — Ruby refactoring
- `clean-code` — clean code rules
- `ponytail` — lazy-correct default
- `clean-architecture` — clean architecture rules
- `rubyn-ruby` — Ruby language deep cuts
- `ui-styling` — shadcn/ui + Tailwind
- `code-complete` — code complete rules
- `ponytail-gain` — ponytail impact scoreboard

MCP servers active:
- `Neon` (`.neon`) — database branch management, schema comparison, query tuning
- `postman` — API discovery/reference (if external data APIs needed; not used here per zero-budget)
- `rails-dev` — Rails development server status, logs, start/stop
- `rails-mcp-server` — Rails project analysis (routes, models, controllers, schema, files)
- `render-mcp-server` — Render deployment services, metrics, logs, deploy tracking

Usage: Skills invoked as needed during implementation; MCP `Neon` available for DB schema verification and migration review.

## Complexity Tracking

No constitution violations requiring justification. System stays minimal: one controller, 5 models, one parser, native Hotwire views.
