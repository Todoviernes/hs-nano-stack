# hs-nano-stack (`hsns`)

A Claude Code plugin that ports the [garagon/nanostack](https://github.com/garagon/nanostack) phase-gated AI workflow into a domain-specialized stack for **HubSpot CMS Hub** development — themes, landing pages, modules, and email templates, written in HubL on top of vanilla CSS variables.

> **Why.** Generalist AI agents leak in three predictable ways on HubSpot: HubL syntax mistakes, schema drift between `theme.json` / `fields.json` / `meta.json`, and skipped marketplace + Core Web Vitals gates. `hsns` solves all three with a phase chain that reads upstream artifacts and refuses to drift.

## The seven commands

```
/hsns:think  →  /hsns:nano  →  /hsns:build  →  /hsns:review  →  /hsns:security  →  /hsns:qa  →  /hsns:ship
```

| Command | What it does | Writes |
|---|---|---|
| `/hsns:think` | CRO/marketer challenges scope: conversion goal, KPI, persona, traffic source | `.hs-nano/think/<TS>.json` |
| `/hsns:nano` | Engineering-manager spec: module map, theme fields, files planned | `.hs-nano/plan/<TS>.json` |
| `/hsns:build` | Scaffolds HubL files, `fields.json`, `meta.json`, `theme.json` from frozen plan | source files |
| `/hsns:review` | HubL correctness, schema integrity, scope-drift detection vs plan | `.hs-nano/review/<TS>.json` |
| `/hsns:security` | HubL XSS, `\|safe` audit, secrets in `module.js`, OWASP for forms | `.hs-nano/security/<TS>.json` |
| `/hsns:qa` | `hs theme validate`, `hs upload --dry-run`, Lighthouse, screenshots, a11y | `.hs-nano/qa/<TS>.json` |
| `/hsns:ship` | `hs upload` to sandbox → preview → optional `--promote` to prod, sprint journal | `.hs-nano/ship/<TS>.json` |

Plus: `/hsns:feature` (additive change, skips `/think`), `/hsns:help` (one-pager).

## Install

```bash
# 1. Install the HubSpot CLI globally
npm install -g @hubspot/cli@latest

# 2. Install this plugin (one of):
#    a) Symlink from a checkout
ln -s "$(pwd)" ~/.claude/plugins/hsns

#    b) Or via Claude Code's plugin command
claude plugins install /path/to/hs-nano-stack
```

## Quickstart

```bash
mkdir my-landing && cd my-landing
git init

# In Claude Code:
/hsns:think                    # scope a landing page; writes & freezes the brief
/hsns:nano                     # produces module map + files_planned; you approve, it freezes
/hsns:build                    # scaffolds HubL/JSON files
/hsns:review                   # checks scope drift, HubL correctness, schema integrity
/hsns:security                 # HubL XSS, secrets, CSP audit
/hsns:qa                       # hs theme validate + Lighthouse + screenshots
/hsns:ship --account=sandbox   # uploads to sandbox portal, generates sprint journal
/hsns:ship --account=prod --promote   # promotes to production after sandbox QA
```

## How the loop stays disciplined

1. **Frozen artifacts.** Once you approve `/hsns:think` or `/hsns:nano`, the JSON is marked `"frozen": true`. Downstream phases must read it and produce consistent output.
2. **Change requests, not silent edits.** When a phase needs to change the spec, it writes `.hs-nano/change-requests/<TS>.json` and asks you. On approval, a new versioned artifact is written; the old one is marked `superseded_by`.
3. **ADR log.** Non-trivial decisions land in `.hs-nano/decisions/NNNN-slug.md`. Every command reads them before generating, so prior choices survive across sessions.
4. **Schema-grounded scaffolds.** `fields.json` keys and `{{ module.<key> }}` references are diffed by `scripts/fields-schema-check.sh`. Mismatch fails review.
5. **No memorized HubL.** When in doubt about a filter or field type, the agent looks up `reference/hubl-cheatsheet.md` and `reference/artifact-schema.md` rather than guessing.

## Setup the HubSpot CLI

See `reference/setup-hs-cli.md` for the full one-time + per-portal flow. Short version:

```bash
hs init                       # writes hubspot.config.yml — auto-added to .gitignore
hs auth                       # add additional portals (sandbox + prod typical)
hs accounts list              # confirm
```

## Versioning & branching

- **Plugin (`plugin.json`):** SemVer. Annotated tags `vX.Y.Z`. `CHANGELOG.md` follows Keep-a-Changelog.
- **Themes (`theme.json`):** SemVer; `/hsns:ship` auto-bumps from review-artifact diff classification.
- **Modules (`module.meta.json`):** integer version per module, bumped on relevant change.
- **Branching (consumer repos):** `main` ≡ production portal · `staging` ≡ sandbox portal · `feat/*` for sprints.
- **Commits:** Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`).

See `docs/CONTRIBUTING.md` for the full rules.

## Targets supported in v0.1

- ✅ CMS Hub themes (full theme starter under `reference/theme-starter/`)
- ✅ Landing pages (drag-drop areas, hero/features/CTA/form recipes)
- ✅ Reusable HubSpot modules (marketplace-shaped `module.html` + `fields.json` + `meta.json`)
- ✅ Email templates (`promotional`, `transactional` — restricted CSS, no JS, mandatory tokens)

## Out of scope for v0.1 (named non-goals)

Serverless functions / private apps · Litmus-style cross-client email previews · `/conductor` parallel execution · `/compound` solution graduation · `guard/rules.json` six-tier safety layer · multi-portal deployment matrix · marketplace-submission packaging.

## License

Apache-2.0. nanostack patterns adapted with attribution.
