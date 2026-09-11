# Project Vision — Tarkov DB

## What this project is

A full-stack Rails application (`tarkov_db`) that transforms `offlinedata/` (MediaWiki wikitext) into structured, queryable data. Zero external dependencies, zero budget.

## Data sources

- `offlinedata/officialwiki/` — wikitext files parsed with `mwparserfromhell`.
- `db/` — PostgreSQL schema and migrations.

## Non-negotiable constraints

1. Full stack: every feature spans data → processing → output.
2. Offlinedata parseable: only open-source parsers (`mwparserfromhell`).
3. Zero dollar budget: no paid APIs, licenses, or hosting.
4. Maximum performance: profiling and optimization mandatory.
5. Minimal complexity (YAGNI): simplest working solution wins.

## Development workflow

- Spec-driven development via spec-kit (`speckit`).
- All PRs/reviews verify: zero-cost compliance, parseability, performance, simplicity.
- Tests cover non-trivial logic with at least one runnable self-check.
