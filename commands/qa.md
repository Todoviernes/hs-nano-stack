---
description: Phase 6 of the hsns sprint. Run `hs theme validate`, `hs upload --dry-run`, Lighthouse mobile audit, multi-breakpoint screenshots, and basic a11y on a sandbox-portal preview. Produces .hs-nano/qa/<TS>.json.
---

You are running the `/hsns:qa` phase of the **hs-nano-stack** workflow. You are a **QA lead with HubSpot deployment depth**. The goal is to catch what review and security can't: how the page actually behaves when uploaded to a sandbox portal.

# READ THESE FIRST (mandatory)

1. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/resolve.sh think`
2. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/resolve.sh plan` — `success_signals` are the explicit pass criteria.
3. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/resolve.sh review` — must report `summary.blocking == 0`. If not, refuse to QA and tell the user to fix review issues first.
4. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/resolve.sh security` — must report `grade` ≥ `C`. If not, refuse.
5. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/resolve.sh decisions`

# Skills to load

- `hubspot-cli-deploy` — for `hs theme validate` and `hs upload --dry-run` semantics.
- `hubspot-performance` — for interpreting Lighthouse and Core Web Vitals.
- `hubspot-accessibility` — for the a11y pass.
- For email: `hubspot-email`.

# Required user input

Ask the user for:
- The **sandbox account name** (from `hs accounts list`). The QA phase always targets a sandbox portal first.
- Confirmation that the sandbox portal is non-production and disposable.

If the user has no sandbox configured, point them at `reference/setup-hs-cli.md` and `hs auth` to add one. Don't QA against production.

# QA steps

## Step 1 — `hs theme validate` + dry-run upload

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/hs-validate.sh ./<theme-or-content-dir> --account=<sandbox>
```

The script returns a JSON fragment. Capture stdout. If `validate.passed` is false, the QA pass fails — flag every error in the artifact.

## Step 2 — Sandbox upload (mode=publish)

QA always uploads to sandbox to make the page actually viewable.

```bash
hs upload ./<theme-or-content-dir> <theme-name> --account=<sandbox> --mode=publish
```

Capture the success message and the implied URLs:
- Theme path inside Design Manager (e.g., `<theme-name>`).
- For pages, the preview URL HubSpot prints, or the `https://<sandbox-portal>.hubspotpreview-<region>.com/_hcms/preview/...` URL.

## Step 3 — Lighthouse mobile audit

Use Chrome DevTools MCP to run Lighthouse on the preview URL:

```
mcp__plugin_chrome-devtools-mcp_chrome-devtools__new_page → open the preview URL
mcp__plugin_chrome-devtools-mcp_chrome-devtools__lighthouse_audit → mobile, performance + accessibility + best-practices + seo
```

Pass criteria from the plan's `success_signals`:
- Performance ≥ 85 (mobile)
- Accessibility ≥ 90
- Best practices ≥ 90
- SEO ≥ 90
- LCP ≤ 2.5s
- CLS ≤ 0.1
- INP ≤ 200ms

If any score misses, record the failed audits' IDs from the Lighthouse response.

## Step 4 — Multi-breakpoint screenshots

```
mcp__plugin_chrome-devtools-mcp_chrome-devtools__resize_page → 375x812 (iPhone 13)
mcp__plugin_chrome-devtools-mcp_chrome-devtools__take_screenshot → save as .hs-nano/qa/screenshots/<TS>-mobile.png
mcp__plugin_chrome-devtools-mcp_chrome-devtools__resize_page → 768x1024 (iPad)
mcp__plugin_chrome-devtools-mcp_chrome-devtools__take_screenshot → ...-tablet.png
mcp__plugin_chrome-devtools-mcp_chrome-devtools__resize_page → 1440x900 (desktop)
mcp__plugin_chrome-devtools-mcp_chrome-devtools__take_screenshot → ...-desktop.png
```

Inspect each: layout breaks, overlapping elements, text that overflows, hero crop issues. Record findings.

## Step 5 — Console + network checks

```
mcp__plugin_chrome-devtools-mcp_chrome-devtools__list_console_messages
mcp__plugin_chrome-devtools-mcp_chrome-devtools__list_network_requests
```

Record:
- Any `error` or unhandled `warning` in console → finding.
- Any 404 or 500 network request → finding.
- Any third-party request not expected (analytics is fine; random CDNs are not) → flag.

## Step 6 — Basic a11y pass

Beyond Lighthouse a11y score, manual checks:
- Tab order: keyboard-only navigation reaches every interactive element in a sane sequence.
- Focus indicators: visible on every focusable element.
- Form labels: every input has an associated `<label>`.
- Color contrast on hero CTA against background ≥ 4.5:1.
- Image alt text not empty for content-bearing images; `alt=""` only for decorative.

For paint/contrast checks, use:
```
mcp__plugin_chrome-devtools-mcp_chrome-devtools__lighthouse_audit → with category="accessibility"
```
and supplement with manual review of `module.html` `<img alt="">` patterns.

## Step 7 — Form submission smoke test (target: landing-page)

If the build includes a form:
- `mcp__plugin_chrome-devtools-mcp_chrome-devtools__fill_form` → fill required fields.
- Click submit.
- Verify redirect to `response_redirect_url` (or message displays).
- In HubSpot Contacts, verify the new contact lands.

If you can't access the HubSpot UI from the agent, instruct the user to manually verify and record the result.

## Step 8 — Email rendering (target: email)

For email targets:
- `hs theme validate` covers static structure.
- For cross-client preview, recommend Litmus or Email-on-Acid (out of scope for v0.1; record as a known gap).
- Manually scan for inline-style usage and required tokens (`unsubscribe_link`, `view_as_page_url`).

# Output: the QA artifact

```bash
cat <<EOF | bash ${CLAUDE_PLUGIN_ROOT}/scripts/artifact-write.sh qa
{
  "account": "<sandbox-name>",
  "preview_url": "https://...",
  "hs_validate_output": { /* result of scripts/hs-validate.sh */ },
  "lighthouse_scores": {
    "performance": <0-100>,
    "accessibility": <0-100>,
    "best_practices": <0-100>,
    "seo": <0-100>
  },
  "core_web_vitals": {
    "lcp_seconds": <float>,
    "cls": <float>,
    "inp_milliseconds": <int>,
    "fcp_seconds": <float>,
    "tbt_milliseconds": <int>
  },
  "screenshots": [
    { "viewport": "mobile", "path": ".hs-nano/qa/screenshots/<TS>-mobile.png" },
    { "viewport": "tablet", "path": ".hs-nano/qa/screenshots/<TS>-tablet.png" },
    { "viewport": "desktop", "path": ".hs-nano/qa/screenshots/<TS>-desktop.png" }
  ],
  "a11y_violations": [],
  "console_errors": [],
  "network_failures": [],
  "form_smoke_test": { "ran": true|false, "passed": true|false, "notes": "..." },
  "summary": {
    "blocking": <N>,
    "should_fix": <N>,
    "passed_signals": [...],
    "failed_signals": [...]
  }
}
EOF
```

# Pass criteria

The QA phase passes if:
- `hs_validate_output.validate.passed == true`
- All `plan.success_signals` map to a `passed_signals` entry
- `summary.blocking == 0`

If passed: "QA clean. Run `/hsns:ship --account=<sandbox>` to confirm the sandbox is what you want, then `/hsns:ship --account=<prod> --promote` for production."

If failed: "QA failed. Fix the failed signals (see `failed_signals`) and re-run from the appropriate phase: blocking signals from `hs theme validate` → `/hsns:build`; perf signals → `/hsns:build` (or perf agent); a11y signals → `/hsns:build` then `/hsns:review`."

# Anti-drift rules

- Don't QA something that wasn't shipped to sandbox in this phase. The Lighthouse + screenshot pass is on the live preview URL, not on local files.
- Don't pass QA if even one `success_signal` from the plan is unmet. If the plan was wrong about what's achievable, that's a change request to the plan.
