---
name: HubSpot CLI & Deploy
description: Use when uploading, watching, validating, or fetching HubSpot CMS content via the `hs` CLI. Covers `hs init`, `hs auth`, `hs upload`, `hs watch`, `hs theme validate`, `hs theme preview`, account targeting, and the per-portal config file.
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

## Common commands

```bash
# Validate a theme directory (marketplace + correctness checks).
hs theme validate ./my-theme

# Watch + auto-upload on save (dev loop).
hs watch ./my-theme my-theme --account=sandbox

# Upload once.
hs upload ./my-theme my-theme --account=sandbox

# Dry-run upload (prints what WOULD upload, no changes).
hs upload ./my-theme my-theme --account=sandbox --dry-run

# Pull a theme/file from a portal to local.
hs fetch my-theme ./my-theme --account=sandbox

# Theme preview server.
hs theme preview ./my-theme --account=sandbox

# Lighthouse-style perf audit on theme assets.
hs cms lighthouse-score --theme=my-theme --account=sandbox
```

**Always pass `--account=<name>`.** Without it, `hs` uses `defaultPortal`, which can silently push to the wrong portal. `commands/ship.md` enforces an explicit `--account` flag.

## `hs upload` arguments

```bash
hs upload <local-src> <remote-dest> [options]
```

- `<local-src>` — your local directory or file (e.g., `./my-theme`).
- `<remote-dest>` — the path inside the portal's Design Manager (e.g., `my-theme`). Conventionally the same as the directory name.
- `--account=<name>` — required by hsns convention.
- `--dry-run` — diff only.
- `--mode=publish|draft` — `publish` updates live pages immediately; `draft` stages for editor review. `commands/ship.md` defaults to `publish` for sandbox, `draft` for prod (then a separate `--promote` step).

## Promotion model (used by `commands/ship.md`)

Two-step ship:

```bash
# Step 1: Sandbox QA.
hs upload ./my-theme my-theme --account=sandbox --mode=publish

# Step 2: After acceptance review on the sandbox preview URL...
hs upload ./my-theme my-theme --account=prod --mode=draft

# Step 3: Inside HubSpot UI, an editor publishes the staged draft.
# (Or with the `--promote` flag in /hsns:ship, we use --mode=publish on prod
#  ONLY when the user explicitly passes --promote and confirms.)
```

This keeps prod pushes deliberate. The phase artifacts (`.hs-nano/qa/<TS>.json`, `.hs-nano/security/<TS>.json`) must be present and timestamped after the latest source change before any prod push is allowed.

## Theme validation gotchas

`hs theme validate` runs three groups of checks:
1. **Required files.** Missing `theme.json`, `fields.json`, or `thumbnail.png`.
2. **Marketplace requirements.** `screenshot_path`, `preview_path`, license, version SemVer.
3. **HubL syntax.** A subset; not as thorough as full Jinjava parsing.

Common warnings:
- `screenshot_path is missing` — for marketplace, you need a real screenshot. For internal use, ignore.
- `version is not SemVer` — the auto-bump in `/hsns:ship` keeps this clean.
- `preview_path does not exist` — broken file reference.

`scripts/hs-validate.sh` runs both `hs theme validate` and `hs upload --dry-run`, normalizes their output to a JSON fragment that `commands/qa.md` writes into the QA artifact.

## When the CLI fails

Common errors and resolutions:

| Error | Resolution |
|---|---|
| `Account not found` | `hs accounts list`; if missing, `hs auth` to add it |
| `Invalid Personal Access Key` | Key was rotated or revoked. Regenerate in HubSpot Settings → Integrations → Private Apps → Personal access key. |
| `Theme not found in portal` | First upload uses `hs upload <local> <new-remote>`; subsequent uploads must match the existing remote name. |
| `Network timeout` | `httpTimeout: 60000` in `hubspot.config.yml`, or check network. |
| `theme.json schema invalid` | Run `hs theme validate` for a precise location. Often a missing comma or wrong type for `responsive_breakpoints`. |

## What `commands/qa.md` and `commands/ship.md` do with the CLI

**QA phase:**
1. `scripts/hs-validate.sh ./my-theme --account=<sandbox>` → JSON fragment.
2. `hs theme preview ./my-theme --account=<sandbox>` → captures the preview URL.
3. Use Chrome DevTools MCP (`lighthouse_audit`, `take_screenshot`) on the preview URL.
4. Aggregate results into `.hs-nano/qa/<TS>.json`.

**Ship phase:**
1. Verify QA artifact is fresher than latest source change.
2. `hs upload ./my-theme my-theme --account=<account> --mode=<mode>`.
3. If `--promote`, run again on prod with `--mode=publish`.
4. Read the upload response, capture preview URL and theme path.
5. Bump `theme.json` version per the review artifact's diff classification.
6. Bump per-module integer versions in `meta.json`.
7. Annotate a git tag `theme/<theme-name>/v<X.Y.Z>-<account>`.
8. Append to `CHANGELOG.md` (if one exists in the consumer repo).
9. Write `.hs-nano/ship/<TS>.json` and `.hs-nano/journal/<TS>-<sprint-name>.md`.
