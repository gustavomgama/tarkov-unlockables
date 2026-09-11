# Tasks: Tarkov Unlockables Access System

**Branch**: `001-tarkov-unlockables-access` | **Feature**: Tarkov Unlockables Access System
**Driven by**: TDD + SpecDD (tests before implementation; spec reviewed before plan; spec approved before tasks)

---

## Phase 1: Setup (TDD + SpecDD Foundation)

- [ ] T001 [P] [US1] Write spec review checklist for unlockables feature (SpecDD gate: spec approved before tasks)
- [ ] T002 [P] [US1] Create parser library structure `lib/parsers/offlinedata_parser.rb` with TDD skeleton (red test first)
- [ ] T003 [P] [US1] Set up test fixtures for `offlinedata/` wikitext samples (TDD: fixtures before parser logic)
- [ ] T004 [P] [US1] Configure `bin/ci` to include parser tests and spec validation (always run, full checks)

---

## Phase 2: Foundational (Blocking Prerequisites — TDD + SpecDD)

- [ ] T005 [P] [US1] Create database migration for Task model with independent PK (no cascade delete) — TDD: migration test first
- [ ] T006 [P] [US1] Create database migration for UnlockableItem model with independent PK — TDD: migration test first
- [ ] T007 [P] [US1] Create database migration for BuyableItem, CraftableItem, BarterableItem subtypes — TDD: migration test first
- [ ] T008 [P] [US1] Write model specs (red-green-refactor) for Task, UnlockableItem, BuyableItem, CraftableItem, BarterableItem
- [ ] T009 [P] [US1] Implement parser with `mwparserfromhell` — TDD: parser tests pass before controller integration
- [ ] T010 [P] [US1] Verify DB independence: delete one record, confirm others intact (TDD: isolation test)

---

## Phase 3: User Story 1 — View Task-Gated Unlockables (P1) [US1]

**Independent Test**: User selects task, sees all unlockables without duplicates, data human-readable.

- [ ] T011 [US1] Implement Task controller `show` action with human-readable output (no raw IDs) — SpecDD: spec §FR-001 verified
- [ ] T012 [US1] Implement UnlockableItem display with acquisition method label (Buy/Craft/Barter) — SpecDD: spec §FR-002 verified
- [ ] T013 [US1] Add Turbo Frame for task unlockables (presentation-layer only, no gun/item mechanics) — SpecDD: spec §Assumptions verified
- [ ] T014 [US1] Write integration test: select task → view unlockables → confirm no duplicates — TDD: test passes before view update
- [ ] T015 [US1] Add performance profiling for unlockable list (SolidCache hot data) — TDD: benchmark test first

---

## Phase 4: User Story 2 — Search and Filter Items (P2) [US2]

**Independent Test**: Search by item name returns accurate task associations; filter by acquisition method works.

- [ ] T016 [US2] Implement search endpoint with item name query — SpecDD: spec §FR-005 verified
- [ ] T017 [US2] Implement filter by acquisition method (buy/craft/barter) — SpecDD: spec §FR-006 verified
- [ ] T018 [US2] Write TDD tests for search accuracy and filter zero false positives — TDD: tests before endpoint
- [ ] T019 [US2] Add human-readable search results (no duplicate info on show pages) — SpecDD: clarification verified
- [ ] T020 [US2] Verify DB independence: search results unaffected by unrelated record deletion — TDD: isolation test

---

## Phase 5: User Story 3 — Track Progression (P3) [US3]

**Independent Test**: Completed tasks show available unlockables; incomplete tasks show locked status.

- [ ] T021 [US3] Implement progression tracking (locked vs available) — SpecDD: spec §FR-007 verified
- [ ] T022 [US3] Write TDD tests for progression state transitions — TDD: red-green-refactor
- [ ] T023 [US3] Add human-readable status indicators (available/locked) — SpecDD: spec §SC-005 verified
- [ ] T024 [US3] Verify checklist updated for new feature rollout — Process: checklist updated before deploy

---

## Phase 6: Favorites Feature (Bounded — TDD + SpecDD)

- [ ] T025 [P] Create `favorite_items` migration (independent PK, restrict delete) — TDD: migration test first
- [ ] T026 [P] Create `FavoriteItem` model with uniqueness validation — TDD: model spec
- [ ] T027 [P] Create `FavoritesController` (presentation-layer create/destroy) — SpecDD: scope verified
- [ ] T028 [P] Add favorites partial (`_favorite.html.erb`) with human-readable buttons — SpecDD: readability
- [ ] T029 [P] Add favorites route (`resources :favorites`) — TDD: route verification
- [ ] T030 [P] Write TDD integration test for favorites (add/remove, independence) — TDD: isolation test

---

## Phase 7: Optimization Verification (TDD + SpecDD + Full-Stack)

- [ ] T031 [P] Check all backend controllers used by frontend routes — TDD: verification
- [ ] T032 [P] Check all frontend views reference backend controllers — SpecDD: verification
- [ ] T033 [P] Identify backend code not used in frontend — TDD: audit
- [ ] T034 [P] Identify frontend code not backed by backend — SpecDD: audit
- [ ] T035 [P] Find dead code (unused methods, models, helpers) — TDD: audit
- [ ] T036 [P] Verify DB indexes cover all query paths — TDD: performance
- [ ] T037 [P] Profile slow queries with `explain` and add missing indexes — TDD: benchmark
- [ ] T038 [P] Verify Turbo/Stimulus efficiency — SpecDD: presentation-layer
- [ ] T039 [P] Confirm no duplicate info on show pages — SpecDD: readability

---

## Phase 8: Polish & Cross-Cutting (TDD + SpecDD + CI)

- [ ] T040 [P] [US1] Run full `bin/ci` pipeline (security, lint, fasterer, test, coverage, audit, docker) — always run
- [ ] T041 [P] [US1] Verify production = development speed (benchmark comparison) — Performance parity
- [ ] T042 [P] [US1] Confirm environment separation (dev/prod separate configs, separate PostgreSQL DBs) — Env separation
- [ ] T043 [P] [US1] Confirm DB independence (independent migrations, backups, restores) — DB separation
- [ ] T044 [P] [US1] Update checklist (`quality.md` or `tdd_specdd.md`) for feature rollout — Process
- [ ] T045 [P] [US1] Final spec review (SpecDD gate): spec approved, clarification resolved, no contradictions

---

## Dependencies

- Phase 2 (Foundational) must complete before Phase 3 (US1)
- Phase 3 (US1) must complete before Phase 4 (US2)
- Phase 4 (US2) must complete before Phase 5 (US3)
- Phase 5 (US3) must complete before Phase 6 (Favorites)
- Phase 6 (Favorites) must complete before Phase 7 (Optimization)
- Phase 7 (Optimization) must complete before Phase 8 (Polish)

## Parallel Opportunities

- T001-T004 (Setup) can run in parallel [P]
- T005-T010 (Foundational DB + parser) can run in parallel [P] once setup complete
- T011-T015 (US1) can run in parallel [P] once foundational complete
- T016-T020 (US2) can run in parallel [P] once US1 complete
- T021-T024 (US3) can run in parallel [P] once US2 complete
- T025-T030 (Favorites) can run in parallel [P] once US3 complete
- T031-T039 (Optimization) can run in parallel [P] once favorites complete
- T040-T045 (Polish) sequential after optimization

## Implementation Strategy

- MVP: User Story 1 (P1) — view task-gated unlockables
- Incremental: US2 (search/filter), US3 (progression), Favorites (bounded), Optimization (full-stack)
- Every task driven by TDD (tests first) and SpecDD (spec reviewed before implementation)
- `bin/ci` always runs; checklist updated per feature rollout
