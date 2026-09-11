# Speckit Full Configuration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Configure spec-kit so it understands this project (tarkov_db) — vision, data (`offlinedata/`), constraints — for agentic SDD.

**Architecture:** Enrich constitution + memory, add extensions/hooks, create project-specific template overrides.

**Tech Stack:** Spec Kit 1.0.6, opencode integration, bash scripts, Markdown.

**Spec:** `docs/superpowers/specs/2026-09-11-speckit-full-config-design.md`

## Global Constraints

- Spec Kit version: 1.0.6
- Integration: opencode (`.` separator)
- Project: Ruby on Rails (`tarkov_db`), PostgreSQL, `offlinedata/` parseable via `mwparserfromhell`
- Budget: $0 (zero-cost)
- No speculative abstractions; minimal changes only.

---

### Task 1: Enrich Constitution with Project Vision

**Files:**
- Modify: `tarkov_spec/.specify/memory/constitution.md`

**Interfaces:**
- Consumes: existing constitution
- Produces: updated constitution with vision/data context

- [ ] **Step 1: Read current constitution**

Read `tarkov_spec/.specify/memory/constitution.md`.

- [ ] **Step 2: Add vision and data sections**

Append to constitution:

```markdown
## Project Vision

This project (`tarkov_db`) is a full-stack Rails application that parses `offlinedata/` (MediaWiki wikitext via `mwparserfromhell`) into structured data, with zero external service dependencies and zero budget. Every feature must respect: full-stack design, parseable offlinedata, $0 cost, maximum performance, minimal complexity (YAGNI).

## Data Context

- Source: `offlinedata/officialwiki/` — parseable wikitext.
- Parser: `mwparserfromhell` (open-source, standard library).
- Constraint: No proprietary or paid parsing tools.
```

- [ ] **Step 3: Bump version**

Update version line to `1.2.0` (MINOR: new vision/data sections).

- [ ] **Step 4: Verify**

Run: `cat tarkov_spec/.specify/memory/constitution.md | grep -E "Project Vision|Data Context|1\.2\.0"`
Expected: all three present.

- [ ] **Step 5: Commit**

```bash
git add tarkov_spec/.specify/memory/constitution.md
git commit -m "docs: enrich constitution with project vision and data context (v1.2.0)"
```

---

### Task 2: Create Project Memory File

**Files:**
- Create: `tarkov_spec/.specify/memory/project-vision.md`

**Interfaces:**
- Consumes: project context (README, offlinedata, AGENTS.md)
- Produces: reference memory file for future specs

- [ ] **Step 1: Write vision file**

```markdown
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
```

- [ ] **Step 2: Verify file exists**

Run: `test -f tarkov_spec/.specify/memory/project-vision.md && echo "OK"`
Expected: OK.

- [ ] **Step 3: Commit**

```bash
git add tarkov_spec/.specify/memory/project-vision.md
git commit -m "docs: add project vision memory for spec-kit"
```

---

### Task 3: Add Extension Hooks

**Files:**
- Create: `tarkov_spec/.specify/extensions.yml`

**Interfaces:**
- Consumes: spec-kit extension schema
- Produces: pre/post command hooks that inject vision

- [ ] **Step 1: Write extensions file**

```yaml
extensions:
  - id: project-context
    enabled: true
    description: Inject project vision into spec-kit commands
    hooks:
      before_constitution:
        - command: speckit.constitution
          optional: false
          prompt: "Remember: this is tarkov_db — full-stack Rails, offlinedata parseable, $0 budget, YAGNI."
      after_constitution:
        - command: speckit.constitution
          optional: true
```

- [ ] **Step 2: Verify YAML parses**

Run: `python3 -c "import yaml; yaml.safe_load(open('tarkov_spec/.specify/extensions.yml'))" && echo "OK"`
Expected: OK.

- [ ] **Step 3: Commit**

```bash
git add tarkov_spec/.specify/extensions.yml
git commit -m "config: add spec-kit extension hooks for project context"
```

---

### Task 4: Create Template Overrides

**Files:**
- Create: `tarkov_spec/.specify/templates/overrides/spec-template.md`
- Create: `tarkov_spec/.specify/templates/overrides/plan-template.md`

**Interfaces:**
- Consumes: core templates (`spec-template.md`, `plan-template.md`)
- Produces: project-specific overrides referencing vision/data

- [ ] **Step 1: Create spec override**

Copy `tarkov_spec/.specify/templates/spec-template.md` to `tarkov_spec/.specify/templates/overrides/spec-template.md` and prepend:

```markdown
<!-- Project: tarkov_db — full-stack Rails, offlinedata parseable, $0 budget, YAGNI -->
```

- [ ] **Step 2: Create plan override**

Copy `tarkov_spec/.specify/templates/plan-template.md` to `tarkov_spec/.specify/templates/overrides/plan-template.md` and prepend:

```markdown
<!-- Project: tarkov_db — vision: full-stack, parseable offlinedata, zero budget, max performance, minimal complexity -->
```

- [ ] **Step 3: Verify overrides resolve**

Run: `bash tarkov_spec/.specify/scripts/bash/resolve-template.sh spec-template --json`
Expected: resolves to override file.

- [ ] **Step 4: Commit**

```bash
git add tarkov_spec/.specify/templates/overrides/
git commit -m "config: add project-specific spec-kit template overrides"
```

---

### Task 5: Create Registry and Preset Structure

**Files:**
- Create: `tarkov_spec/.specify/.registry`
- Create: `tarkov_spec/.specify/presets/default/templates/` (directory)

**Interfaces:**
- Consumes: spec-kit registry schema
- Produces: minimal registry + preset scaffold

- [ ] **Step 1: Write registry**

```json
{"extensions":{"project-context":{"enabled":true,"priority":1}},"presets":{"default":{"enabled":true,"priority":1}}}
```

- [ ] **Step 2: Create preset directory**

Run: `mkdir -p tarkov_spec/.specify/presets/default/templates`

- [ ] **Step 3: Verify registry parses**

Run: `python3 -c "import json; json.load(open('tarkov_spec/.specify/.registry'))" && echo "OK"`
Expected: OK.

- [ ] **Step 4: Commit**

```bash
git add tarkov_spec/.specify/.registry tarkov_spec/.specify/presets/
git commit -m "config: add spec-kit registry and preset scaffold"
```

---

### Task 6: Verify Full Configuration

**Files:**
- Modify: none (verification only)

**Interfaces:**
- Consumes: all previous tasks
- Produces: confirmation that spec-kit is ready

- [ ] **Step 1: Run prerequisites check**

Run: `bash tarkov_spec/.specify/scripts/bash/check-prerequisites.sh --json`
Expected: `FEATURE_DIR` points to feature, `AVAILABLE_DOCS` includes docs.

- [ ] **Step 2: Verify constitution version**

Run: `grep "Version" tarkov_spec/.specify/memory/constitution.md`
Expected: `1.2.0`.

- [ ] **Step 3: Verify memory file**

Run: `test -f tarkov_spec/.specify/memory/project-vision.md && echo "vision OK"`
Expected: vision OK.

- [ ] **Step 4: Verify extensions**

Run: `test -f tarkov_spec/.specify/extensions.yml && echo "extensions OK"`
Expected: extensions OK.

- [ ] **Step 5: Verify overrides**

Run: `ls tarkov_spec/.specify/templates/overrides/`
Expected: `spec-template.md`, `plan-template.md`.

- [ ] **Step 6: Final commit**

```bash
git add -A
git commit -m "config: fully configure spec-kit for agentic SDD (vision, data, hooks, overrides, registry)"
```

---

## Self-Review

1. **Spec coverage:** All design sections covered (constitution, memory, extensions, overrides, registry).
2. **Placeholder scan:** No TBD/placeholder text in code blocks.
3. **Type consistency:** File paths and command names consistent across tasks.

Plan saved to `docs/superpowers/plans/2026-09-11-speckit-full-config.md`.
