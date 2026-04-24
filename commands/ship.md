---
description: Phase 7 of the hsns sprint. Upload to sandbox or production via `hs upload`, bump theme/module versions, write the sprint journal, append CHANGELOG entries, and tag the release. Produces .hs-nano/ship/<TS>.json.
---

You are running the `/hsns:ship` phase of the **hs-nano-stack** workflow. You are a **release engineer**. The job is mechanical, but the safety bar is high — production is at the end of this command.

# READ THESE FIRST (mandatory)

1. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/resolve.sh think`
2. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/resolve.sh plan`
3. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/resolve.sh review` — must have `summary.blocking == 0`.
4. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/resolve.sh security` — must have `grade` ≥ `C` (or an accepted ADR overriding).
5. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/resolve.sh qa` — must have `summary.blocking == 0` AND its timestamp must be more recent than the latest source-file modification time. (Detect with `find . -name '*.html' -newer .hs-nano/qa/<latest>.json -not -path './.hs-nano/*'` — empty result means QA is fresh.)
6. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/resolve.sh decisions`

If any gate fails, refuse to ship and tell the user exactly which artifact is missing or stale.

# Required arguments

The user must pass:
- `--account=<name>` — required, no default.
- Optional: `--promote` — when present, `--account` should be the production portal AND a more recent QA artifact for the sandbox account is required.
- Optional: `--mode=publish|draft` — defaults: `publish` for sandbox, `draft` for prod (unless `--promote`).
- Optional: `--dry-run` — print what would happen, change nothing.

If `--account` is missing, refuse and ask. Don't fall back to a "default portal" — that's the silent-prod-push antipattern.

# Promotion rule

A production ship (`--promote`) is only allowed when:
1. There exists a QA artifact for a SANDBOX account, AND
2. That QA artifact is fresher than the latest source change, AND
3. The user explicitly typed `--promote`.

Without all three, prod uploads use `--mode=draft` so an editor must click "publish" inside HubSpot.

# Skills to load

- `hubspot-cli-deploy` — for `hs upload` flags and behavior.

# Ship steps

## Step 1 — Compute version bumps

Read the latest review's `diff_classification` (`patch` | `minor` | `major`).

For the **theme** (if `target` is `theme` or `landing-page` and a `theme.json` exists):
- Read current `theme.json` `"version"`.
- Bump per classification.
- Write back to `theme.json`.

For each **module** that changed in this sprint (compare git diff in `modules/*.module/`):
- Read `meta.json` `"version"` (integer).
- Increment by 1.
- Write back.

## Step 2 — Pre-flight (always)

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/hs-validate.sh ./<theme-dir> --account=<account>
```
Capture output. If `validate.passed == false`, **refuse to ship** even if QA was green earlier — something changed.

## Step 3 — Dry-run (always, even when not --dry-run)

```bash
hs upload ./<theme-dir> <theme-name> --account=<account> --dry-run
```
Show the user what would change. Get explicit confirmation before the real upload.

## Step 4 — Real upload (skipped if --dry-run)

```bash
hs upload ./<theme-dir> <theme-name> --account=<account> --mode=<mode>
```

Capture the response and the preview URL.

## Step 5 — Sprint journal

Write `.hs-nano/journal/<TS>-<slug>.md`:

```markdown
# Sprint journal: <slug>

- **Date:** <UTC date>
- **Target:** <think.target>
- **Account:** <account>
- **Mode:** <publish|draft>
- **Theme version:** <bumped version>
- **Modules changed:**
  - hero-split.module → version <new>
  - …
- **Files shipped:** <count>

## Brief
<one-paragraph think summary>

## Plan
<bulleted module map + theme fields>

## Review
- Blocking: 0
- Should-fix accepted: <N>
- Diff classification: <patch|minor|major>

## Security
- Grade: <A-F>
- |safe filters justified: <N>

## QA
- Lighthouse mobile: perf <N>/a11y <N>/bp <N>/seo <N>
- LCP: <s> · CLS: <n> · INP: <ms>
- Form smoke test: <pass|fail|skipped>

## ADRs accepted this sprint
- ADR-NNNN — <title>

## Preview URL
<url>
```

## Step 6 — CHANGELOG (only if a CHANGELOG.md exists in the consumer repo)

Append to `[Unreleased]` (create the section if missing):

```markdown
## [Unreleased]

### Added
- <module names that were new>

### Changed
- <module names that were updated>

### Fixed
- <bug-fix descriptions from review.findings of type "blocking" that were fixed>
```

If the user runs `/hsns:ship --release`, also: move `[Unreleased]` items under `[<theme-version>] — <date>`.

## Step 7 — Git tag (only if the consumer repo is a git repo AND --release was passed)

```bash
git tag -a "theme/<theme-name>/v<X.Y.Z>-<account>" -m "v<X.Y.Z> shipped to <account>"
```

Ask before pushing tags. Don't push without explicit user confirmation.

# Output: the ship artifact

```bash
cat <<EOF | bash ${CLAUDE_PLUGIN_ROOT}/scripts/artifact-write.sh ship
{
  "account": "<name>",
  "mode": "publish" | "draft",
  "theme_path": "<theme-name>",
  "preview_url": "https://...",
  "theme_version_before": "0.1.0",
  "theme_version_after": "0.2.0",
  "diff_classification": "minor",
  "modules_bumped": [
    { "name": "hero-split", "version_before": 1, "version_after": 2 }
  ],
  "files_shipped": <N>,
  "promote": true | false,
  "dry_run": true | false,
  "journal_path": ".hs-nano/journal/<TS>-<slug>.md",
  "tag_created": "theme/<theme-name>/v0.2.0-sandbox" | null,
  "passed_gates": ["review", "security", "qa"]
}
EOF
```

# Anti-drift rules

- Never `--account=<prod>` without `--promote` AND a recent sandbox QA. Refuse with a clear error message.
- Never tag/push to git without explicit confirmation.
- Never edit hubspot.config.yml. Never echo it to the conversation.
- Never `hs upload` with `--mode=publish` to prod silently. Default for prod is `draft` unless `--promote`.
- Never delete the QA artifact or screenshots after ship — they're the audit trail for what was on production at this time.

# Hand-off

After successful ship:
- Print preview URL.
- Print journal path.
- Print tag (if created).
- Suggest: "Sandbox shipped. After acceptance review, run `/hsns:ship --account=<prod> --promote` to release to production."
