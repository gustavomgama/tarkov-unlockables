# Frontend Design Skills & Plugins — User Guide

*Installed 2026-09-10. Skills live in `~/.agents/skills/` and are symlinked into `~/.opencode/skills/` so OpenCode picks them up automatically. Restart OpenCode (or start a new session) to load them.*

---

## 1. What was installed

| Skill | Source | What it does |
|---|---|---|
| **frontend-design** | `anthropics/skills` (canonical Anthropic skill) | Anti-"AI slop" frontend design: bold aesthetic direction, distinctive typography/color, production-grade code. |
| **ui-ux-pro-max** | `TANUJ0071/opencode-skills` | Design intelligence database: 50+ styles, 161 color palettes, 57 font pairings, 99 UX guidelines, 25 chart types, 15 stacks — searchable via a local CLI. |
| **advanced-frontend-uiux** | `TANUJ0071/opencode-skills` | Elite visual effects: WebGL, Three.js, GSAP animations, cutting-edge free libraries. |
| **playwright-testing** | `TANUJ0071/opencode-skills` | E2E testing with Playwright — page objects, cross-browser, CI. Use it to *verify* the UI the other skills build. |

Already installed before this session (design pack you already had):

| Skill | Use it for |
|---|---|
| **design** | Umbrella skill: logos (55 styles), CIP, banners, icons, social photos, slides |
| **banner-design** | Social media / ads / hero / print banners (22 styles) |
| **brand** | Brand voice, visual identity, messaging, style guides |
| **design-system** | Token architecture (primitive → semantic → component), component specs |
| **slides** | HTML presentations with Chart.js |
| **ui-styling** | shadcn/ui + Tailwind implementation, dark mode, accessible components |

---

## 2. How to invoke them

You never need to remember exact names — just ask naturally. OpenCode matches the task to the skill's description and loads it.

```
"Build a landing page for the tarkov_db item database"        → frontend-design
"Make the items index look premium, dark military theme"      → frontend-design + ui-ux-pro-max
"What font pairing and palette for a tactical dashboard?"     → ui-ux-pro-max
"Add a 3D animated hero with GSAP"                            → advanced-frontend-uiux
"Design a banner for the Discord server"                      → banner-design
"Create a logo for the project"                               → design
"Write E2E tests for the item search flow"                    → playwright-testing
```

Force a specific skill by naming it: *"use ui-ux-pro-max to pick a color palette"*.

---

## 3. ui-ux-pro-max — the searchable design database

This one has a real CLI you can also run yourself:

```bash
~/.pyvenv-tarkov/bin/python ~/.agents/skills/ui-ux-pro-max/scripts/search.py "QUERY" [options]
```

Useful flags:

```bash
--domain style|color|chart|landing|product|ux|typography|icons|react|web|google-fonts
--stack react|nextjs|vue|svelte|html-tailwind|shadcn|threejs|...   (15 stacks)
--design-system                    # generate a full design-system brief
--project-name "tarkov_db"         # names the generated system
--format markdown|ascii --json
--persist --output-dir docs/       # write the design system to files
```

Examples:

```bash
# Pick a visual style for a dark tactical dashboard
... search.py "dark tactical military dashboard" --domain style

# Font pairing for an editorial look
... search.py "editorial magazine serif" --domain typography

# Full design system for this Rails app, persisted to docs/
... search.py "tarkov game database dark mode" --design-system \
    --project-name tarkov_db --persist --output-dir docs/design
```

Each result gives: palette hex codes, effects, WCAG accessibility rating, framework compatibility score, an AI-prompt keyword block, CSS variables, and an implementation checklist — everything the agent (or you) needs to implement consistently.

---

## 4. Recommended workflows

### A. New page / component (the standard loop)
1. **frontend-design** — commits to a bold aesthetic direction, writes the code.
2. **ui-ux-pro-max** — supplies the palette, font pairing, and UX rules so choices are grounded, not guessed.
3. **playwright-testing** — verifies it works in a real browser.

Prompt example: *"Redesign the items index page. Use frontend-design for the aesthetic, query ui-ux-pro-max for a dark tactical style and font pairing, then add Playwright tests for search and filters."*

### B. Brand-first work
1. **brand** → define voice/identity first.
2. **design-system** → turn it into tokens (colors, spacing, type scale).
3. **frontend-design** / **ui-styling** → implement against those tokens.

### C. Marketing assets
- **banner-design** for banners, **design** for logos/icons/social photos, **slides** for presentations.

### D. This Rails app specifically
The app uses **Tailwind CSS v4 + Hotwire + ViewComponent**. Best stack match in ui-ux-pro-max: `--stack html-tailwind` or `--stack shadcn`. When asking for UI work, mention "Tailwind + ViewComponent" so the skills generate idiomatic code (partials/components, ERB, not React).

---

## 5. Managing skills

```bash
npx skills ls -g                 # list installed skills
npx skills add <repo>@<skill> -g -y   # install another
npx skills update                # update to latest
npx skills remove                # uninstall
```

Browse more: https://skills.sh — search "frontend", "ui", "design". Install target is `~/.agents/skills/`; if a new skill doesn't appear in OpenCode, symlink it:

```bash
ln -sfn ~/.agents/skills/<name> ~/.opencode/skills/<name>
```

---

## 6. Notes & caveats

- **frontend-design** deliberately avoids generic fonts (Inter, Roboto) and purple-gradient-on-white clichés — expect opinionated choices. Tell it your constraints (e.g. "must match existing Tailwind theme") if you want continuity instead.
- **advanced-frontend-uiux** pulls heavy libraries (Three.js, GSAP) — fine for one-off pages, overkill for the Rails app's server-rendered views unless you specifically want a 3D hero.
- **ui-ux-pro-max** scripts need the project venv Python (`~/.pyvenv-tarkov/bin/python`) — system Python is PEP 668 locked.
- **playwright-testing** assumes Playwright is set up in the project; this project currently uses Capybara/Selenium for system tests — use the skill for new standalone E2E suites, or ask it to adapt patterns to Capybara.
- Skills run with full agent permissions — review any newly installed SKILL.md before trusting it (the `npx skills` installer prints this warning too).
