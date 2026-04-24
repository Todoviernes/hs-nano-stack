# Contributing & Workflow Rules

These rules apply to **the `hs-nano-stack` plugin repo itself** AND to **HubSpot content repos that use this plugin**. Where they differ, the rule says so.

---

## Versioning

### The plugin (this repo)

- **SemVer** in `.claude-plugin/plugin.json` `"version"` field.
- **Bump rules:**
  - `MAJOR` — incompatible changes to the artifact JSON schema, the command interface, or the plugin manifest shape.
  - `MINOR` — new commands, skills, agents, or recipes; backwards-compatible enhancements.
  - `PATCH` — bug fixes, doc tweaks, recipe content updates that don't break existing consumers.
- **Pre-releases:** `v0.2.0-rc.1`, `v0.2.0-beta.1`. Never tag `latest` mutably.
- **Tags:** annotated only, format `vMAJOR.MINOR.PATCH`. `git tag -a v0.1.0 -m "v0.1.0 — ..."`.
- **CHANGELOG.md** follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Sections per release: Added / Changed / Fixed / Removed / Deprecated / Security.

### HubSpot content (themes, modules, landings — produced by consumers)

- **Theme version** — SemVer in `theme.json` `"version"`. Auto-bumped by `/hsns:ship` based on the latest `review` artifact's diff classification:
  - blocking-fix or HubL bugfix → `PATCH`
  - new module / new field / new section → `MINOR`
  - breaking field rename, removed module, changed `template_type` → `MAJOR`
- **Module version** — integer in each `module.meta.json` `"version"`. HubSpot uses an integer per module; bump by 1 whenever the module's HubL or `fields.json` changes.
- **Per-portal tag** — each `/hsns:ship` writes an annotated tag `theme/<theme-name>/v<X.Y.Z>-<portal-name>`, so `git log --all --tags` shows what is live where.

---

## Branching

### Plugin repo

Trunk-based. Short-lived branches.

- `main` — protected, always green, always tagged for the latest release.
- `feat/<short-desc>` — new commands, skills, agents, recipes.
- `fix/<short-desc>` — bug fixes.
- `docs/<short-desc>` — documentation only.
- `chore/<short-desc>` — refactors, deps, infra, no behavior change.
- `refactor/<short-desc>` — internal restructuring.

PR-only into `main`. No direct pushes. PRs require: green checks (when CI exists), updated CHANGELOG.md `[Unreleased]` section, and (for new components) a one-line entry in `README.md`.

### HubSpot content repos (consumers)

`main` mirrors **production portal**; `staging` mirrors **sandbox portal**. Branches model deployment state, not dev convenience.

```
main         ←── production portal (live to customers)
staging      ←── sandbox portal (QA/preview)
feat/*       ←── in-progress sprints; merged into staging after /hsns:qa passes
```

Promotion path:
1. `feat/<sprint>` → run `/hsns:think → /hsns:nano → /hsns:build → /hsns:review → /hsns:security → /hsns:qa`.
2. Merge `feat/<sprint>` into `staging` once `/hsns:qa` artifact reports zero blocking findings.
3. `/hsns:ship --account=<sandbox>` uploads the staging branch to the sandbox portal and writes a sprint journal.
4. After acceptance review on the sandbox preview URL, fast-forward `staging` into `main` and `/hsns:ship --account=<prod> --promote`.

**No long-lived `develop` branch.** The phase-gate artifacts (`.hs-nano/qa/*.json`, `.hs-nano/security/*.json`) are the gating signal — branch state is just a ledger of where things actually live.

---

## Commits

[Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) on every commit, in both repos.

```
<type>(<scope>): <subject>

<body — explains WHY, not what>

<optional footer — refs, breaking-change notes, ADR refs>
```

**Types:** `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `perf`, `build`, `ci`, `revert`.

**Scope examples (plugin):** `commands`, `skills`, `agents`, `scripts`, `recipes`, `theme-starter`, `manifest`.

**Scope examples (HubSpot content):** `hero-split`, `theme`, `landing-demo`, `email-promo`, `fields`.

**Examples:**
```
feat(commands): add /hsns:feature for additive changes that skip /think

Reason: small follow-on tasks were forced through the full think gate, which
felt like overhead. /feature jumps straight to /nano with the prior plan as
context.

Refs: ADR-0007.
```

```
fix(scripts): hs-validate.sh exits 0 even when `hs theme validate` warns

Reason: warnings (e.g., missing screenshot_path) should not block the QA
artifact from being written. They land in qa.json `warnings[]` instead.
```

**Body explains WHY.** What is in the diff. Don't repeat it.

**Breaking changes** get a `BREAKING CHANGE:` footer **and** a MAJOR bump.

---

## Decision discipline

Before opening a PR that introduces a non-trivial choice (a new command, a workflow change, a recipe pattern), write an ADR in `docs/decisions/NNNN-slug.md` (plugin repo) or `.hs-nano/decisions/NNNN-slug.md` (consumer repo). Sections:

```markdown
# ADR NNNN — <title>

- **Status:** Proposed | Accepted | Superseded by ADR-MMMM
- **Date:** YYYY-MM-DD

## Context
What's the situation? What constraints?

## Decision
What did we choose, exactly?

## Consequences
What gets easier? What gets harder?

## Alternatives considered
What did we look at and reject, and why?
```

ADRs are append-only. Never edit an accepted ADR — write a superseding one and mark the old as `Superseded by ADR-NNNN`.

---

## Anti-drift checklist (for the agent, automatic)

Every `/hsns:*` command opens with a "READ THESE FIRST" block that forces:

1. Read latest non-superseded `.hs-nano/think/*.json`.
2. Read latest non-superseded `.hs-nano/plan/*.json`.
3. Read all `Status: Accepted` ADRs in `.hs-nano/decisions/`.
4. Read most recent `.hs-nano/review/*.json` `scope_drift` and `conflicts`.
5. If any upstream artifact is `"frozen": true`, treat it as immutable — change requests only.

This is enforced by the command body, not by hooks. The discipline is structural, not behavioral.

---

## Releasing the plugin

1. Move `[Unreleased]` items in `CHANGELOG.md` under a new `[X.Y.Z] — YYYY-MM-DD` header.
2. Bump `.claude-plugin/plugin.json` `"version"` to `X.Y.Z`.
3. Commit: `chore(release): vX.Y.Z`.
4. Tag: `git tag -a vX.Y.Z -m "vX.Y.Z — <one-line summary>"`.
5. Push branch + tag: `git push origin main --follow-tags`.
6. Create a GitHub release pasting the matching CHANGELOG section.

That's it. Never edit a published tag. If something is broken, ship `vX.Y.Z+1`.
