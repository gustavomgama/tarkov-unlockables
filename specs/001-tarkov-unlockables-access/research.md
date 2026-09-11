# Research: Tarkov Unlockables Access System

## Decisions

- **Stack**: Rails 8.1.3 + PostgreSQL + Hotwire/Turbo/Stimulus + SolidCache/SolidQueue/SolidCable + TailwindCSS + Propshaft. Confirmed by project Gemfile and `.ruby-version`.
- **Parsing**: `mwparserfromhell` 0.7.2 (installed in `~/.pyvenv-tarkov`) for `offlinedata/` wikitext. Zero-cost, open-source.
- **DB Independence**: Each record (Task, UnlockableItem, BuyableItem, CraftableItem, BarterableItem) has independent primary keys; no foreign-key cascading deletes; soft-delete or independent deletion only.
- **Performance**: SolidCache for hot unlockable lists; Propshaft for asset pipeline; profiling with `benchmark` for parser; no speculative caching layers.
- **Presentation**: Human-readable data via Rails helpers + Tailwind; no duplicate info on show pages (each item shown once with acquisition method clearly labeled); no functional gun/item mechanics.

## Alternatives Considered

- React/Vue frontend: Rejected — violates YAGNI and zero-cost simplicity; Hotwire native covers full-stack needs.
- Redis for cache: Rejected — SolidCache (Rails 8 native) covers it; no extra dependency.
- Separate microservice for parser: Rejected — violates full-stack simplicity; parser lives in `lib/`.

## Rationale

The constitution demands full stack, zero budget, maximum speed, minimal complexity. The chosen stack matches existing project (Rails 8.1.3, PostgreSQL) and adds only what's needed: parser library, native Hotwire, Solid gems, Tailwind. DB independence ensures a single corrupted record doesn't cascade.
