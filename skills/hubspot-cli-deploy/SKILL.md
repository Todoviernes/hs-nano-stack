---
name: HubSpot CLI & Deploy
description: Use when uploading, watching, validating, or fetching HubSpot CMS content via the `hs` CLI. Covers `hs init`, `hs auth`, `hs cms upload`, `hs cms watch`, `hs cms theme marketplace-validate`, `hs cms theme preview`, account targeting, and the per-portal config file. Modern (>= 7.x) CLI uses the `hs cms` subtree; the older `hs upload` / `hs watch` / `hs theme` forms still work as deprecated aliases.
version: 1.0.0
---

# HubSpot CLI (`hs`) — auth, validate, upload

The HubSpot CLI is the single integration point between your local theme repo and a HubSpot portal. `hs-nano-stack` never re-implements what `hs` already does — `commands/qa.md` and `commands/ship.md` shell out to it.

## Install

```bash
npm install -g @hubspot/cli@latest
hs --version       # >= 7.0
```

If `hs` is missing, the QA and ship phases refuse to run; `commands/help.md` and `reference/setup-hs-cli.md` direct the user to install.

## One-time auth flow

`hs init` walks the user through Personal Access Key (PAK) auth interactively. The user must do this themselves (it opens a browser; the agent should not run it without confirmation).

```bash
hs init
# 1. Opens browser → HubSpot prompts user to log in (if not already).
# 2. Settings → Integrations → Private Apps → Personal access key.
# 3. User clicks "Show key", copies it, pastes into the terminal.
# 4. CLI writes hubspot.config.yml in the current dir (or ~/hubspot.config.yml if --global).
```

Add additional portals (sandbox + production typical):
```bash
hs auth                       # interactive — same flow, appends a portal
hs accounts list              # confirm both registered
hs accounts use sandbox       # set default
hs accounts rename old new    # rename a portal
hs accounts remove name       # remove
```

## `hubspot.config.yml`

Written by `hs init` / `hs auth`. The shape:

```yaml
defaultPortal: sandbox
portals:
  - name: sandbox
    portalId: 1234567
    authType: personalaccesskey
    personalAccessKey: <SECRET>
  - name: prod
    portalId: 7654321
    authType: personalaccesskey
    personalAccessKey: <SECRET>
allowUsageTracking: false
httpTimeout: 30000
```

**Security rules** (enforced by `scripts/init-project.sh` + `commands/security.md`):
- `hubspot.config.yml` is **never** committed (added to `.gitignore` automatically).
- `hubspot.config.yml.example` is the committed stub with `personalAccessKey: REPLACE_ME_FROM_HUBSPOT_SETTINGS` — devs copy it, fill in their key, never commit the filled version.
- The agent must never `cat`, `echo`, or paste the contents of a real `hubspot.config.yml` into the conversation.

## Common commands (modern `hs cms` form)

```bash
# Watch + auto-upload on save (dev loop).
hs cms watch ./my-theme my-theme --account=sandbox

# Upload once.
hs cms upload ./my-theme my-theme --account=sandbox

# Pull a theme/file from a portal to local.
hs cms fetch my-theme ./my-theme --account=sandbox

# Theme preview server.
hs cms theme preview --src=./my-theme --account=sandbox

# Lighthouse-style perf audit on theme assets.
hs cms lighthouse-score --theme=my-theme --account=sandbox

# Marketplace-validate a theme that's ALREADY UPLOADED.
hs cms theme marketplace-validate my-theme --account=sandbox
```

> **No local-only `validate`.** As of CLI 7.x, the only theme validator is `hs cms theme marketplace-validate`, which targets a remote (already-uploaded) theme path. There is no `hs theme validate ./local-dir` despite older docs implying one. For pre-upload local checks, use `scripts/hs-validate.sh` (covered below).

**Always pass `--account=<name>`.** Without it, `hs` uses `defaultPortal`, which can silently push to the wrong portal. `commands/ship.md` enforces an explicit `--account` flag.

**Old `hs upload` / `hs theme` / `hs watch` forms still work** as deprecated aliases — they print a deprecation warning and run the new code under the hood. Prefer `hs cms ...` in scripts.

## `hs cms upload` arguments

```bash
hs cms upload <local-src> <remote-dest> [options]
```

- `<local-src>` — your local directory or file (e.g., `./my-theme`).
- `<remote-dest>` — the path inside the portal's Design Manager (e.g., `my-theme`). Conventionally the same as the directory name.
- `--account=<name>` — required by hsns convention.
- `--cms-publish-mode=publish|draft` — `publish` updates live pages immediately; `draft` stages for editor review. `commands/ship.md` defaults to `publish` for sandbox, `draft` for prod (then a separate `--promote` step).
- `--clean` — deletes the destination before upload. Dangerous; gated behind explicit user approval in `/hsns:ship`.
- `--force` — skips confirmation prompts on a `--clean` upload. Never used by hsns.

> **No `--dry-run` on `hs cms upload`.** The CLI doesn't expose one. Pre-upload sanity checks live in `scripts/hs-validate.sh` (local schema check). Anything that needs a real "what would change" diff is post-upload only — and even then HubSpot doesn't surface a structured diff.

## Promotion model (used by `commands/ship.md`)

Two-step ship:

```bash
# Step 1: Sandbox QA.
hs cms upload ./my-theme my-theme --account=sandbox --cms-publish-mode=publish

# Step 2: After acceptance review on the sandbox preview URL...
hs cms upload ./my-theme my-theme --account=prod --cms-publish-mode=draft

# Step 3: Inside HubSpot UI, an editor publishes the staged draft.
# (Or with the `--promote` flag in /hsns:ship, we use --cms-publish-mode=publish on prod
#  ONLY when the user explicitly passes --promote and confirms.)
```

This keeps prod pushes deliberate. The phase artifacts (`.hs-nano/qa/<TS>.json`, `.hs-nano/security/<TS>.json`) must be present and timestamped after the latest source change before any prod push is allowed.

## Theme validation: two layers

### Layer 1 — local schema check (`scripts/hs-validate.sh` without `--account`)

Pure-jq check; no portal needed; runs in <1 second:
- `theme.json` exists, parses, has `label` / `version` (SemVer) / `preview_path`.
- `fields.json` (if present) is a top-level array.
- Every `modules/*.module/` has `module.html`, `fields.json`, `meta.json`.
- Every module's `meta.json` has `label`, `version` (integer), `host_template_types` (array), `is_available_for_new_content` (boolean).
- Every `templates/*.html` annotated `templateType: page` or `landing-page` includes `{{ standard_header_includes }}` and `{{ standard_footer_includes }}`.

This is what `/hsns:qa` runs PRE-upload to fail fast on shape errors.

### Layer 2 — portal-side marketplace-validate (`scripts/hs-validate.sh` with `--account` + `--remote`)

Runs `hs cms theme marketplace-validate <remote-path> --account=<name>` against an already-uploaded theme. Required for marketplace submission; optional otherwise. Catches things like:
- `screenshot_path` references a real file in the portal.
- All field types in `fields.json` are valid HubSpot types.
- License + version metadata pass marketplace rules.

Common warnings:
- `screenshot_path missing` — for marketplace, you need a real screenshot. For internal-only use, ignore.
- `version is not SemVer` — `/hsns:ship`'s auto-bump keeps this clean.
- `preview_path does not exist` — broken file reference.

The unified output of both layers is the JSON fragment `commands/qa.md` writes into `qa.hs_validate_output`.

## When the CLI fails

Common errors and resolutions:

| Error | Resolution |
|---|---|
| `Account not found` | `hs accounts list`; if missing, `hs auth` to add it |
| `Invalid Personal Access Key` | Key was rotated or revoked. Regenerate in HubSpot Settings → Integrations → Private Apps → Personal access key. |
| `Theme not found in portal` | First upload uses `hs upload <local> <new-remote>`; subsequent uploads must match the existing remote name. |
| `Network timeout` | `httpTimeout: 60000` in `hubspot.config.yml`, or check network. |
| `theme.json schema invalid` | Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/hs-validate.sh ./theme` for a precise location. Often a missing comma or wrong type for `responsive_breakpoints`. |

## What `commands/qa.md` and `commands/ship.md` do with the CLI

**QA phase:**
1. `scripts/hs-validate.sh ./my-theme` → layer-1 local schema check (no portal).
2. `hs cms upload ./my-theme my-theme --account=<sandbox> --cms-publish-mode=publish` → upload to sandbox.
3. `scripts/hs-validate.sh ./my-theme --account=<sandbox> --remote=my-theme` → layer-2 marketplace-validate (now possible since uploaded).
4. `hs cms theme preview --src=./my-theme --account=<sandbox>` → captures the preview URL.
5. Use Chrome DevTools MCP (`lighthouse_audit`, `take_screenshot`) on the preview URL.
6. Aggregate results into `.hs-nano/qa/<TS>.json`.

**Ship phase:**
1. Verify QA artifact is fresher than latest source change.
2. `hs cms upload ./my-theme my-theme --account=<account> --cms-publish-mode=<mode>`.
3. If `--promote`, run again on prod with `--cms-publish-mode=publish`.
4. Read the upload response, capture preview URL and theme path.
5. Bump `theme.json` version per the review artifact's diff classification.
6. Bump per-module integer versions in `meta.json`.
7. Annotate a git tag `theme/<theme-name>/v<X.Y.Z>-<account>`.
8. Append to `CHANGELOG.md` (if one exists in the consumer repo).
9. Write `.hs-nano/ship/<TS>.json` and `.hs-nano/journal/<TS>-<sprint-name>.md`.
