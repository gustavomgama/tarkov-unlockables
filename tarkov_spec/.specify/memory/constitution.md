# Tarkov DB Constitution

## Core Principles

### I. Full Stack Application
Every feature must be designed as a full-stack solution — from data parsing through user-facing output — without external service dependencies that violate the zero-budget constraint. The system must function end-to-end within its own architecture.

### II. Offlinedata Parseable
All data sourced from `offlinedata/` must be parseable using standard, open-source parsing libraries (e.g., `mwparserfromhell` for wikitext). No proprietary or paid parsing tools. Data integrity and parseability are non-negotiable.

### III. Zero Dollar Budget
No paid services, APIs, licenses, or infrastructure costs. Every dependency must be free and open-source. If a feature requires a paid component, it must be redesigned or excluded.

### IV. Maximum Performance
The system must be optimized for speed at every layer — parsing, processing, and response. Performance is a first-class requirement, not an afterthought. Use the fastest available algorithms and minimize overhead.

### V. Minimal Complexity (YAGNI)
Only build what is explicitly needed. No speculative abstractions, no scaffolding for future features, and no over-engineering. The simplest working solution is the correct one.

## Additional Constraints

- Technology stack: Ruby on Rails (existing), PostgreSQL, open-source libraries only.
- Data source: `offlinedata/` directory — parseable, version-controlled, no external APIs.
- Budget: $0 — no paid dependencies, hosting, or services.
- Performance target: Fastest possible response times; profiling and optimization are mandatory for non-trivial logic.
- Security: Basic input validation at trust boundaries; no security measures may be simplified away.

## Development Workflow

- All changes must comply with the constitution principles above.
- Code review must verify: zero-cost compliance, parseability of data sources, performance impact, and simplicity.
- Complexity must be justified; unnecessary abstractions must be removed.
- Tests must cover non-trivial logic with at least one runnable self-check.

## Project Vision

This project (`tarkov_db`) is a full-stack Rails application that parses `offlinedata/` (MediaWiki wikitext via `mwparserfromhell`) into structured data, with zero external service dependencies and zero budget. Every feature must respect: full-stack design, parseable offlinedata, $0 cost, maximum performance, minimal complexity (YAGNI).

## Data Context

- Source: `offlinedata/officialwiki/` — wikitext files parsed with `mwparserfromhell`.
- Parser: `mwparserfromhell` (open-source, standard library).
- Constraint: No proprietary or paid parsing tools.

## Governance

This constitution supersedes all other practices. Amendments require documentation, approval, and a version bump. All PRs/reviews must verify compliance with these principles.

**Version**: 1.2.0 | **Ratified**: 2025-09-11 | **Last Amended**: 2026-09-11

<!-- Sync Impact Report -->
<!-- Version change: 1.1.0 → 1.2.0 -->
<!-- Modified principles: None -->
<!-- Added sections: Project Vision, Data Context -->
<!-- Removed sections: None -->
<!-- Deferred items: None -->
