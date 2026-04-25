# Testing & validation

Three layers of validation, increasing in realism. Run them in order — each is a precondition for the next being meaningful.

---

## Layer 1 — Script-level smoke test (no portal, no Claude Code)

Repeatable, fast (<5s), zero credentials required. Covers everything the plugin can verify locally.

```bash
bash tests/smoke.sh
```

What it checks:

| # | Layer | What it verifies |
|---|---|---|
| 1 | Manifest | `.claude-plugin/plugin.json` is valid JSON with `name` and `version`. |
| 2 | Scripts shape | All 7 `scripts/*.sh` are executable and start with `#!/usr/bin/env bash`. |
| 3 | Artifact loop | `init-project` → `artifact-write` → `resolve` works end-to-end, including the freeze flag, the empty-phase case, and `superseded_by` skipping. |
| 4 | HubL lint | All 11 reference HTML files pass with zero errors. |
| 5 | JSON parse | Every `.json` under the repo root parses with `jq`. |
| 6 | Theme schema | `hs-validate.sh` (layer 1, local) passes on the `theme-starter` materialized into `/tmp`. |
| 7 | Fields ↔ HubL | `fields-schema-check.sh` correctly accepts a clean module and rejects a broken one. |

Expected output: **20 passed, 0 failed.**

```
[smoke] result: 20 passed, 0 failed
```

If anything fails, the failing layer prints the underlying error.

### When to re-run smoke

- Before tagging any release.
- After editing any script under `scripts/`.
- After editing any reference HTML/JSON under `reference/`.
- After modifying `tests/smoke.sh` itself (sanity-check the change).

---

## Layer 2 — Plugin static validation

Verifies the plugin manifest, command frontmatter, agent frontmatter, skill structure, and that every `${CLAUDE_PLUGIN_ROOT}/scripts/*.sh` reference resolves.

This was run via the `plugin-dev:plugin-validator` agent during initial build. To re-run:

In Claude Code, invoke the agent against this directory:
> "Validate the plugin at `/Users/todoviernes/Documents/TodoViernes/hs-nano-stack/`"

Expected verdict: **PASS** with no must-fix or should-fix items. Stylistic nitpicks are acceptable.

---

## Layer 3 — End-to-end interactive sprint (requires sandbox portal)

The real test: run an actual sprint through the seven phases against a sandbox HubSpot portal.

### Prerequisites

1. **Plugin installed in Claude Code.**
   ```bash
   ln -s /Users/todoviernes/Documents/TodoViernes/hs-nano-stack ~/.claude/plugins/hsns
   ```
   Restart Claude Code so it picks up the plugin.

2. **HubSpot CLI authenticated to a sandbox portal.**
   See `reference/setup-hs-cli.md`. Verify with:
   ```bash
   hs accounts list                # should list your sandbox
   hs accounts use sandbox
   ```

3. **A scratch directory.** Don't run this against an existing important repo.
   ```bash
   mkdir /tmp/hsns-e2e && cd /tmp/hsns-e2e
   git init
   ```

### The seven-phase smoke run

In Claude Code, in `/tmp/hsns-e2e`:

| Step | Action | Expected outcome |
|---|---|---|
| 1 | `/hsns:think` — answer the prompts: target=landing-page, goal=demo bookings, KPI=submissions/1k, persona=ops manager, traffic=paid LinkedIn, voice=direct, scope=hero+3 features+form. | Brief written to `.hs-nano/think/<TS>.json`, marked `frozen: true` after your approval. |
| 2 | `/hsns:nano` | Plan written to `.hs-nano/plan/<TS>.json` with module_map (hero-split, feature-grid, cta-form), files_planned, content_schema, risks, success_signals. Approved + frozen. |
| 3 | `/hsns:build` | Files appear: `theme.json`, `fields.json`, `css/main.css`, `templates/landing-demo.html`, three `modules/*.module/` directories, `partials/{header,footer}.html`. |
| 4 | `/hsns:review` | `.hs-nano/review/<TS>.json` written. Expect `summary.blocking == 0`. If `scope_drift.status == "drift_detected"`, the build added files that weren't in `files_planned` — that's a real bug to investigate. |
| 5 | `/hsns:security` | `.hs-nano/security/<TS>.json` with `grade: A` (or B). Zero blocking findings on a clean scaffold. |
| 6 | `/hsns:qa` (with `--account=<sandbox>`) | Layer-1 schema passes. Sandbox upload succeeds. Layer-2 marketplace-validate runs. Lighthouse mobile ≥ 85. Screenshots captured at three breakpoints. `qa.summary.blocking == 0`. |
| 7 | `/hsns:ship --account=<sandbox> --dry-run` | Prints what would happen without uploading. |
| 7b | `/hsns:ship --account=<sandbox>` | Uploads to sandbox; sprint journal written to `.hs-nano/journal/`. |
| 7c | (optional) `/hsns:ship --account=<prod> --promote` | Uploads to prod with `--cms-publish-mode=draft` (an editor must publish from HubSpot UI). |

### Pass criteria

- Each phase's artifact appears in `.hs-nano/<phase>/` with a recent timestamp.
- No phase emits blocking findings on the agent's own scaffolds. (If it does, the recipes have bugs.)
- The sandbox preview URL renders the landing with the planned modules.
- The form embed renders and submits a test contact into HubSpot.
- Lighthouse mobile performance ≥ 85.

### What to do if a phase fails

| Failure | Likely cause | Fix |
|---|---|---|
| `/hsns:review` flags drift | Build wrote a file not in `files_planned`. | Fix the recipe used; re-run. |
| `/hsns:security` finds `\|safe` | The recipe has an unjustified `\|safe`. | Add `{# safe-justified: <reason> #}` or remove. |
| `/hsns:qa` layer-1 schema fails | Build wrote a malformed `meta.json` / `theme.json`. | Inspect `qa.hs_validate_output.local_check.findings`. |
| `/hsns:qa` upload fails | Wrong `--account`, expired PAK, missing permission. | `hs accounts list`; regenerate PAK if needed. |
| `/hsns:qa` Lighthouse < 85 | Hero image too large, missing `fetchpriority`, etc. | `hs-perf-reviewer` agent's findings tell you exactly. |
| `/hsns:ship` refuses | Older artifact than source change. | Re-run review / security / qa. |

---

## Continuous integration

CI is configured in [`.github/workflows/smoke.yml`](../.github/workflows/smoke.yml). It runs `tests/smoke.sh` on every push to `main` and on every pull request. The workflow installs Node 20, the latest `@hubspot/cli`, and then executes the 20-layer smoke. Status is shown by the badge at the top of the README.

Locally:

```bash
bash tests/smoke.sh
```

CI runs the same script, so a green local run plus a green CI run cover the same surface — modulo macOS vs. Linux behavior differences in `sed` / `bash`. If something passes locally but fails in CI, that delta is the bug.

---

## Manual sanity checks (per-component)

If you suspect one specific piece, run it in isolation:

```bash
# A specific recipe — does it lint clean?
bash scripts/hubl-lint.sh reference/module-recipes/hero-split.html

# A handcrafted module — do fields match HubL?
bash scripts/fields-schema-check.sh path/to/some.module/

# Theme starter — does layer 1 schema pass?
bash scripts/hs-validate.sh reference/theme-starter

# An ADR — is it picked up?
bash scripts/resolve.sh decisions

# A think artifact — does freeze work?
echo '{"target":"module","scope":"x"}' | bash scripts/artifact-write.sh think
bash scripts/resolve.sh think
```

---

## Reporting issues

Open an issue at https://github.com/Todoviernes/hs-nano-stack/issues with:

1. The exact `tests/smoke.sh` output (full).
2. `git rev-parse HEAD` (to pin the version).
3. `hs --version`, `node --version`, `jq --version`, `bash --version`.
4. Whether you have the HubSpot Developer MCP installed (`hs mcp setup --client claude`).

The smoke test is intentionally noisy on failure to make this easy.
