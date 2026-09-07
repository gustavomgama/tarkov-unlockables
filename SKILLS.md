# Skills Reference

All **45** AI skills installed in `~/.opencode/skills/`, with trigger phrases/commands
and full descriptions.

## Quick Access — `Ctrl+P` then type `>skills`

```
>skills task-observer      → Monitors task execution, skill improvement opportunities
>skills ponytail           → Anti-over-engineering, laziest solution
>skills ponytail-review    → Code review for over-engineering
>skills ponytail-audit     → Whole-repo over-engineering audit
>skills ponytail-debt      → List deferred ponytail shortcuts
>skills ponytail-gain      → Ponytail impact scoreboard
>skills ponytail-help      → Ponytail quick reference
>skills clean-code         → Clean Code rules (Uncle Bob)
>skills refactoring       → Refactoring rules (Fowler)
>skills refactoring-guru  → Refactoring patterns
>skills clean-architecture → Clean Architecture boundaries
>skills domain-driven-design → DDD aggregates, ubiquitous language
>skills nuke-on-rails     → Rails health & security audit
>skills ui-styling        → shadcn/ui, Tailwind, accessible components
>skills design-system      → Token architecture, component specs
>skills design            → Brand, logo, banner, icon generation
>skills ruby-version-manager → Detect Ruby version manager first
>skills ruby-resource-map  → Ruby docs, typing, tooling sources
>skills ruby-test-frameworks → minitest vs test-unit gotchas
>skills rubyn-rails        → Rails patterns and gotchasas
>skills rubyn-rspec        → RSpec patterns
>skills rubyn-minitest     → Minitest patterns
>skills rubyn-ruby         → Ruby language deep cuts
>skills rubyn-gems         → Gem guidance (devise, sidekiq, etc.)
```

Type `>skills` followed by any skill name above to activate it instantly.

---

asdi

## How activation works

- Skills load **at session start** — after installing/removing one, restart opencode.
- They trigger **automatically** when your request matches the skill's description
("review this controller for Clean Code violations" → `clean-code`).
- You can also invoke **explicitly** by naming them: *"use ponytail-review on this diff"*,
*"apply refactoring-guru rules here"*.
- Each skill is a folder with a `SKILL.md`; open one anytime to read its full instructions.

---

## 1. Task Observer — `one-skill-to-rule-them-all` (1)


| Skill           | Trigger phrases                                                                                                                | Full description                                                                                                                                                                                                                                                                                                                                                        |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `task-observer` | "task observer", "One Skill to Rule Them All", any mention of skill observations/improvements, observation log, skill taxonomy | Monitors task execution for skill improvement opportunities. Use during **any** multi-step task, agentic workflow, or substantive work session where tools produce deliverables. Captures patterns, user corrections, workflow insights, and methodology worth preserving as reusable skills. Also fires during post-task feedback discussions ("what did you learn?"). |


**Use:** invoke at session start, leave running during work; afterwards ask *"what skill opportunities did you notice?"*

## 2. UI/UX pack — ui-ux-pro-max (6)


| Skill           | Trigger words/actions                                                                                                                                           | Full description                                                                                                                                                                                                                                                                                                                                                                                                           |
| --------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `design`        | design logo, create CIP, generate mockups, build slides, design banner, generate icon, create social photos, social media images, brand identity, design system | Umbrella skill: brand identity, design tokens, UI styling, logo generation (**55 styles**, Gemini AI), corporate identity program (**50 CIP deliverables** w/ mockups), HTML presentations (Chart.js), banner design (22 styles), icon design (**15 styles**, SVG, Gemini 3.1 Pro), social photos (HTML→screenshot). Platforms: Facebook, Twitter/X, LinkedIn, YouTube, Instagram, Pinterest, TikTok, Threads, Google Ads. |
| `design-system` | design tokens, systematic design, brand-compliant presentations                                                                                                 | Token architecture, component specifications, slide generation. Three-layer tokens (primitive→semantic→component), CSS variables, spacing/typography scales, component specs, strategic slide creation.                                                                                                                                                                                                                    |
| `ui-styling`    | building UIs, design systems, responsive layouts, accessible components, themes/dark mode, posters                                                              | Beautiful, accessible interfaces with shadcn/ui (Radix UI + Tailwind), Tailwind utility-first styling, canvas-based visuals. Covers dialogs, dropdowns, forms, tables; theme customization, dark mode, visual designs/posters, consistent styling patterns.                                                                                                                                                                |
| `brand`         | branded content, tone of voice, marketing assets, brand compliance, style guides                                                                                | Brand voice, visual identity, messaging frameworks, asset management, brand consistency.                                                                                                                                                                                                                                                                                                                                   |
| `banner-design` | design/create/generate banner                                                                                                                                   | Banners for social media, ads, website heroes, creative assets, print; multiple art directions with AI-generated visuals. Platforms: Facebook, Twitter/X, LinkedIn, YouTube, Instagram, Google Display, website hero, print. Styles: minimalist, gradient, bold typography, photo-based, illustrated, geometric, retro, glassmorphism, 3D, neon, duotone, editorial, collage.                                              |
| `slides`        | presentations, decks, slide strategies                                                                                                                          | Strategic HTML presentations with Chart.js, design tokens, responsive layouts, copywriting formulas, and contextual slide strategies.                                                                                                                                                                                                                                                                                      |


**Use:** *"style the items table using ui-styling"*, *"create a design-system spec for our badges"*.
Image-generation features optionally use your own `GEMINI_API_KEY`.

## 3. Engineering books — agent-rules-books (14)

Distilled rule sets from the named book; each triggers when you name its book or its principles:


| Skill                                             | Trigger phrases                                | Full description                                                                                                                                                                      |
| ------------------------------------------------- | ---------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `clean-code`                                      | "clean code", Uncle Bob rules                  | Software design rules distilled from the *Clean Code* book. Use when writing or reviewing code that should follow Clean Code principles, or when the user mentions this book by name. |
| `refactoring`                                     | refactoring moves/smells                       | Rules distilled from *Refactoring* (Fowler). Writing or reviewing code that should follow Refactoring principles.                                                                     |
| `refactoring-guru`                                | refactor patterns, Refactoring Guru            | Rules distilled from the *Refactoring Guru* book. Same activation pattern.                                                                                                            |
| `clean-architecture`                              | Clean Architecture, boundaries                 | Rules distilled from the *Clean Architecture* book.                                                                                                                                   |
| `domain-driven-design`                            | DDD, aggregates, ubiquitous language           | Rules distilled from the *Domain Driven Design* book.                                                                                                                                 |
| `domain-driven-design-distilled`                  | DDD Distilled                                  | Rules distilled from the *Domain Driven Design Distilled* book.                                                                                                                       |
| `implementing-domain-driven-design`               | Implementing DDD, Vernon                       | Rules distilled from the *Implementing Domain Driven Design* book.                                                                                                                    |
| `working-effectively-with-legacy-code`            | legacy code, seam, sprout method               | Rules distilled from the *Working Effectively With Legacy Code* book.                                                                                                                 |
| `the-pragmatic-programmer`                        | pragmatic, DRY, tracer bullets                 | Rules distilled from the *The Pragmatic Programmer* book.                                                                                                                             |
| `code-complete`                                   | Code Complete, McConnell                       | Rules distilled from the *Code Complete* book.                                                                                                                                        |
| `release-it`                                      | production readiness, stability patterns       | Rules distilled from the *Release It* book.                                                                                                                                           |
| `patterns-of-enterprise-application-architecture` | PoEAA, ActiveRecord pattern, Fowler enterprise | Rules distilled from the *Patterns Of Enterprise Application Architecture* book.                                                                                                      |
| `designing-data-intensive-applications`           | DDIA, data systems                             | Rules distilled from the *Designing Data Intensive Applications* book.                                                                                                                |
| `a-philosophy-of-software-design`                 | software philosophy, deep modules              | Rules distilled from the *A Philosophy Of Software Design* book.                                                                                                                      |


**Use:** *"refactor ItemsController following clean-code"*, *"review this migration against DDIA principles"*. Full rule files live inside each skill folder.

## 4. Ponytail — anti-over-engineering (6)


| Skill             | Commands/triggers                                                                                                                                                                                | Full description                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ponytail`        | `/ponytail`, "ponytail", "be lazy", "lazy mode", "simplest solution", "minimal solution", "yagni", "do less", "shortest path"; complaints about over-engineering/bloat/boilerplate/unneeded deps | Persistent mode: forces the **laziest solution that actually works** — simplest, shortest, most minimal. Senior-dev channel: question whether the task needs to exist at all (YAGNI), stdlib before custom code, native platform features before dependencies, one line before fifty. Intensity levels: `lite`, `full` (default), `ultra`. Use on ANY coding task (writing, adding, refactoring, fixing, reviewing, designing, library choice). NOT for non-coding requests. |
| `ponytail-review` | `/ponytail-review`, "review for over-engineering", "what can we delete", "is this over-engineering", "simplify review"                                                                           | Code review focused exclusively on over-engineering. Finds what to delete: reinvented standard library, unneeded dependencies, speculative abstractions, dead flexibility. One line per finding: location, what to cut, what replaces it. Complements correctness-focused review.                                                                                                                                                                                            |
| `ponytail-audit`  | `/ponytail-audit`, "audit this codebase", "audit for over-engineering", "what can I delete from this repo", "find bloat"                                                                         | Whole-repo audit for over-engineering. Like ponytail-review but scans the entire codebase instead of a diff: ranked list of what to delete, simplify, or replace with stdlib/native equivalents. One-shot report, does not apply fixes.                                                                                                                                                                                                                                      |
| `ponytail-debt`   | `/ponytail-debt`, "ponytail debt", "what did ponytail defer", "list the shortcuts", "ponytail ledger"                                                                                            | Harvests every `ponytail:` comment in the codebase into a debt ledger, so deliberate shortcuts and deferrals get tracked instead of rotting into "later means never". One-shot report, changes nothing.                                                                                                                                                                                                                                                                      |
| `ponytail-gain`   | `/ponytail-gain`, "ponytail gain", "what does ponytail save", "ponytail scoreboard"                                                                                                              | Shows ponytail's measured impact as a compact scoreboard: less code, less cost, more speed (benchmark medians). One-shot display, not a persistent mode; not a per-repo number.                                                                                                                                                                                                                                                                                              |
| `ponytail-help`   | `/ponytail-help`, "ponytail help", "what ponytail commands", "how do I use ponytail"                                                                                                             | Quick-reference card for all ponytail modes, skills, and commands. One-shot display.                                                                                                                                                                                                                                                                                                                                                                                         |


**Use:** *"ponytail-review my last diff"* before pushing; *"run ponytail-audit on app/services"*.

## 5. Rails audit — nuke-on-rails (1)


| Skill           | Trigger phrases                                                                                       | Full description                                                                                                                                                                                                                                                                                                           |
| --------------- | ----------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `nuke-on-rails` | "nuke on rails", Rails project audit, security and health check, deep review of a vibecoded Rails app | Principal-engineer Rails health & security audit. Runs rubycritic, Brakeman, bundler-audit and ruby_audit; triages every finding with the LLM as judge; brings an OWASP Top 10 arsenal of checks for what scanners miss; returns one impact-ranked action plan. Explicit invocation only (model auto-invocation disabled). |


**Use:** *"run nuke on rails on this project"* — expect it to shell out to the scanners.

## 6. Ruby pack — rubyn-code (13) + ruby-skills (3) + Cursor (1)

### rubyn-* reference libraries (rubyn-code project; trigger by topic)


| Skill                   | Trigger phrases                                                                    | Full description                                                                                                                                                                                                                                                                                                                                                                                                                        |
| ----------------------- | ---------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `rubyn-ruby`            | Ruby language topics                                                               | Deep cuts: strings, result objects, pattern matching, regexps. Reference files: blocks_procs_lambdas, classes, concurrency, data_struct_openstruct, debugging_profiling, enumerable_patterns, exception_handling, file_io, hashes, metaprogramming, modules, pattern_matching, regular_expressions, result_objects, strings.                                                                                                            |
| `rubyn-ruby_project`    | project setup/conventions                                                          | Project conventions: structure, rake tasks, bundler dependencies, CLI tools. Files: bundler_dependencies, cli_tools, rake_tasks, structure.                                                                                                                                                                                                                                                                                             |
| `rubyn-rails`           | Rails patterns/gotchas                                                             | Rails-specific patterns. Files: action_cable, active_record_basics, active_storage, api_design, associations, background_jobs, caching, callbacks, concerns_controllers, concerns_models, controllers, engines, form_objects, hotwire, internationalization, logging, mailers, migrations, multitenancy, n_plus_one, presenters, query_objects, routing, scopes, security, serializers, service_objects, testing_strategy, validations. |
| `rubyn-sinatra`         | Sinatra apps                                                                       | Sinatra app patterns: application_structure, middleware_and_deployment, testing.                                                                                                                                                                                                                                                                                                                                                        |
| `rubyn-solid`           | SOLID principles                                                                   | SOLID with concrete Ruby examples: dependency_inversion, interface_segregation, liskov_substitution, open_closed, single_responsibility.                                                                                                                                                                                                                                                                                                |
| `rubyn-minitest`        | minitest tests                                                                     | Minitest patterns: assertions, fixtures, integration_tests, mailers_and_jobs, mocking_stubbing, service_tests_and_performance, structure_and_conventions, system_tests. Deceptively similar APIs to test-unit cause NoMethodError at runtime.                                                                                                                                                                                           |
| `rubyn-rspec`           | rspec specs                                                                        | RSpec patterns: build_stubbed, factory_design, let_vs_let_bang, mocking_stubbing, request_specs, service_specs, shared_examples, system_specs, test_performance.                                                                                                                                                                                                                                                                        |
| `rubyn-refactoring`     | refactoring moves                                                                  | Moves and heuristics: code_smells, command_query_separation, encapsulate_collection, extract_class, extract_method, replace_conditional, value_objects.                                                                                                                                                                                                                                                                                 |
| `rubyn-code_quality`    | code quality standards                                                             | Quality checks and standards: fits_in_your_head, naming_conventions, null_object, technical_debt, value_objects, yagni.                                                                                                                                                                                                                                                                                                                 |
| `rubyn-design_patterns` | GoF patterns in Ruby                                                               | Classic design patterns: adapter, bridge_memento_visitor, builder, command, composite, decorator, facade, factory_method, iterator, mediator, observer, proxy, singleton, state, strategy, template_method.                                                                                                                                                                                                                             |
| `rubyn-gems`            | gem guidance                                                                       | Gem authoring and dependency guidance: devise, dry_rb, factory_bot, faraday, graphql_ruby, pundit, redis, rubocop, sidekiq, stripe.                                                                                                                                                                                                                                                                                                     |
| `rubyn-self_test`       | validating rubyn guidance                                                          | How rubyn-code validates its own guidance: chisel_sample.rb, chisel_smoke.rb.                                                                                                                                                                                                                                                                                                                                                           |
| `rubyn-megaplan`        | "megaplan", "mega plan", "plan phases", "phase this out", features spanning 3+ PRs | Phased project planning. Interviews the user one question at a time, then scaffolds numbered phase folders (requirements/design/tasks). Vertical slices, not horizontal layers — each phase merges cleanly and leaves trunk working. Skip for single-PR features, pure research, or fast-shifting shapes.                                                                                                                               |


### st0012's Ruby navigation/testing tooling


| Skill                  | Trigger conditions                                                  | Full description                                                                                                                                                                                                           |
| ---------------------- | ------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ruby-resource-map`    | working in any Ruby project                                         | Authoritative sources for documentation, typing, and tooling.                                                                                                                                                              |
| `ruby-test-frameworks` | writing/running tests in minitest or test-unit projects             | Framework guides have deceptively similar APIs with critical naming differences that cause NoMethodError at runtime. Consult before writing assertions, running specific tests, or using setup/teardown lifecycle methods. |
| `ruby-version-manager` | session start in projects with Gemfile/.ruby-version/.tool-versions | Detect the version manager BEFORE running ruby, bundle, gem, rake, rails, rspec, or any Ruby command.                                                                                                                      |


### Cursor IDE config


| Skill                       | Trigger phrases                                                                                                        | Full description                                                                           |
| --------------------------- | ---------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| `cursor-api-key-management` | "cursor api key", "cursor openai key", "cursor anthropic key", "own api key cursor", "BYOK cursor", "cursor azure key" | Configure BYOK API keys for OpenAI, Anthropic, Google, Azure, and custom models in Cursor. |


---

## Suggested habits for this project

1. **Before committing**: `ponytail-review` the diff → then commit.
2. **While writing Rails code**: name the relevant book (`clean-code`, `refactoring`) so rules apply as we type.
3. **Frontend changes**: `ui-styling` / `design-system` keep Bootstrap markup consistent.
4. **Monthly**: `ponytail-debt` to revisit deferred shortcuts; `task-observer` to bank new skills.
5. **Schema/data questions**: none of these replace `HANDOFF.md` — check it first.

---

Total: **45 skills installed** — all documented above (1 + 6 + 14 + 6 + 1 + 13 + 3 + 1).

*Note: ponytail's repo also targets a "Hermes" chat harness (*`/ponytail`* *slash commands) — here those strings act as plain natural-language triggers, only the skill bundles are installed.*
