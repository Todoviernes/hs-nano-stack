# Artifact schema

Canonical JSON shapes for each phase artifact. Every command writes via `scripts/artifact-write.sh`, which adds `phase`, `timestamp`, `schema_version`, `frozen` automatically. The shapes below show the *content* fields each phase contributes.

`schema_version` is currently `1`. Bumping it requires updating this doc + a MAJOR version bump on the plugin.

## Common envelope (added by `scripts/artifact-write.sh`)

```json
{
  "phase": "<phase>",
  "timestamp": "20260424T160000Z",
  "schema_version": 1,
  "frozen": false,
  "superseded_by": null
}
```

Once user-approved, `frozen` is set to `true` (in-place via `jq`). When a subsequent artifact replaces this one (after a change request), `superseded_by` is set to the basename of the replacement (without `.json`).

## `.hs-nano/think/<TS>.json`

```json
{
  "phase": "think",
  "target": "landing-page",
  "conversion_goal": "demo bookings",
  "primary_kpi": "form submissions / 1k visits",
  "persona": "ops manager, mid-market SaaS",
  "traffic_source": "paid LinkedIn",
  "brand_voice": "direct, technical, no fluff",
  "scope": "single landing page, hero + 3 features + form",
  "out_of_scope": ["pricing page", "blog integration"],
  "premise": "validated"
}
```

`target`: enum `theme | landing-page | module | email`.
`premise`: `validated | needs_validation`.

## `.hs-nano/plan/<TS>.json`

```json
{
  "phase": "nano",
  "target": "landing-page",
  "template_type": "landing-page",
  "dnd_strategy": "single-area",
  "module_map": [
    {
      "name": "hero-split",
      "recipe": "hero-split",
      "drag_drop": false,
      "purpose": "Above-the-fold conversion",
      "fields": ["headline", "subhead", "image", "cta"]
    }
  ],
  "theme_fields": ["colors.primary", "colors.secondary", "typography.heading", "max_width"],
  "templates_planned": ["templates/landing-demo.html"],
  "partials_planned": ["partials/header.html", "partials/footer.html"],
  "sections_planned": [],
  "files_planned": ["theme.json", "fields.json", "css/main.css", "templates/landing-demo.html", "..."],
  "content_schema": {
    "hero": { "headline": "...", "subhead": "...", "cta_label": "...", "cta_url": "..." },
    "features": [ { "headline": "...", "body": "..." } ]
  },
  "risks": [
    { "id": "R-1", "description": "form embed CSS conflicts", "mitigated_by": "scope module.css to .hs-form-wrapper" }
  ],
  "success_signals": [
    "lighthouse mobile performance ≥ 85",
    "fields-schema-check.sh exits 0",
    "scripts/hs-validate.sh passes (layer 1)"
  ]
}
```

`template_type`: enum `page | landing-page | blog-post | blog-listing | email | system | none`.
`dnd_strategy`: enum `single-area | multi-area | fixed`.

## `.hs-nano/review/<TS>.json`

```json
{
  "phase": "review",
  "mode": "standard",
  "summary": {
    "blocking": 0,
    "should_fix": 2,
    "nitpicks": 1,
    "positive": 3
  },
  "scope_drift": {
    "status": "in_scope",
    "out_of_scope_files": [],
    "missing_files": []
  },
  "diff_classification": "patch",
  "findings": [
    {
      "id": "REV-001",
      "type": "should_fix",
      "category": "hubl-syntax",
      "description": "...",
      "location": "modules/hero-split.module/module.html:42",
      "suggestion": "..."
    }
  ],
  "conflicts": []
}
```

`mode`: `quick | standard | thorough` (default `standard`).
`scope_drift.status`: `in_scope | drift_detected`.
`diff_classification`: `patch | minor | major` — drives `/hsns:ship`'s theme version bump.
`findings[].type`: `blocking | should_fix | nitpick | positive`.
`findings[].category`: `hubl-syntax | fields-schema | scope-drift | brand-voice | performance | conversion-flow | meta-json | theme-tokens | email-required-tokens`.

## `.hs-nano/security/<TS>.json`

```json
{
  "phase": "security",
  "mode": "standard",
  "summary": { "blocking": 0, "should_fix": 1, "nitpicks": 0, "positive": 2 },
  "grade": "A",
  "findings": [
    {
      "id": "SEC-001",
      "type": "should_fix",
      "category": "hubl-xss",
      "owasp_ref": "A03:2021-Injection",
      "description": "...",
      "location": "modules/hero-split.module/module.html:14",
      "suggestion": "..."
    }
  ],
  "conflicts_with_review": []
}
```

`grade`: `A | B | C | D | F`.
`findings[].category`: `hubl-xss | secrets | form-integrity | csp | owasp | compliance`.

## `.hs-nano/qa/<TS>.json`

```json
{
  "phase": "qa",
  "account": "sandbox",
  "preview_url": "https://12345-sandbox.hubspotpreview-na1.com/_hcms/preview/...",
  "hs_validate_output": {
    "theme_src": "./my-theme",
    "validate": { "exit_code": 0, "passed": true, "log": "..." },
    "upload_dry_run": { "exit_code": 0, "passed": true, "ran": true, "log": "..." }
  },
  "lighthouse_scores": {
    "performance": 89,
    "accessibility": 95,
    "best_practices": 92,
    "seo": 100
  },
  "core_web_vitals": {
    "lcp_seconds": 2.1,
    "cls": 0.04,
    "inp_milliseconds": 120,
    "fcp_seconds": 1.4,
    "tbt_milliseconds": 80
  },
  "screenshots": [
    { "viewport": "mobile",  "path": ".hs-nano/qa/screenshots/<TS>-mobile.png" },
    { "viewport": "tablet",  "path": ".hs-nano/qa/screenshots/<TS>-tablet.png" },
    { "viewport": "desktop", "path": ".hs-nano/qa/screenshots/<TS>-desktop.png" }
  ],
  "a11y_violations": [],
  "console_errors": [],
  "network_failures": [],
  "form_smoke_test": { "ran": true, "passed": true, "notes": "submitted; contact appeared in HubSpot" },
  "summary": {
    "blocking": 0,
    "should_fix": 0,
    "passed_signals": ["lighthouse mobile performance ≥ 85", "fields-schema-check.sh exits 0"],
    "failed_signals": []
  }
}
```

## `.hs-nano/ship/<TS>.json`

```json
{
  "phase": "ship",
  "account": "sandbox",
  "mode": "publish",
  "theme_path": "my-theme",
  "preview_url": "https://12345-sandbox.hubspotpreview-na1.com/...",
  "theme_version_before": "0.1.0",
  "theme_version_after": "0.2.0",
  "diff_classification": "minor",
  "modules_bumped": [
    { "name": "hero-split", "version_before": 1, "version_after": 2 }
  ],
  "files_shipped": 14,
  "promote": false,
  "dry_run": false,
  "journal_path": ".hs-nano/journal/20260424T163000Z-demo-launch.md",
  "tag_created": "theme/my-theme/v0.2.0-sandbox",
  "passed_gates": ["review", "security", "qa"]
}
```

`mode`: `publish | draft`.

## `.hs-nano/change-requests/<TS>.json`

```json
{
  "phase": "change-requests",
  "from_phase": "build",
  "target_artifact": ".hs-nano/plan/20260424T160000Z.json",
  "field_to_change": "module_map",
  "rationale": "form-stack recipe needs a hidden field for UTM capture; not in original plan",
  "proposed_diff": { "add": [{ "name": "utm-capture", "drag_drop": false, "purpose": "track campaign source", "fields": ["utm_source","utm_medium","utm_campaign"] }] },
  "status": "pending"
}
```

`status`: `pending | approved | rejected`.
On `approved`: a NEW artifact is written to the relevant phase, and the original is in-place edited to `superseded_by: <new-artifact-basename>`.

## `.hs-nano/decisions/NNNN-slug.md`

Markdown, not JSON. Numbered sequentially. Append-only — to revise, write a new ADR that supersedes the old one.

```markdown
# ADR NNNN — <title>

- **Status:** Proposed | Accepted | Superseded by ADR-MMMM
- **Date:** YYYY-MM-DD

## Context
...

## Decision
...

## Consequences
...

## Alternatives considered
...
```

## `.hs-nano/journal/<TS>-<slug>.md`

Markdown. Written by `/hsns:ship` only. Reads all upstream artifacts and produces a human-readable sprint summary. See `commands/ship.md` for the template.
