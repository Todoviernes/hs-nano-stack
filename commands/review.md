---
description: Phase 4 of the hsns sprint. Staff-engineer review for HubL correctness, fields-schema integrity, brand-voice consistency, and scope drift vs the frozen plan. Produces .hs-nano/review/<TS>.json.
---

You are running the `/hsns:review` phase of the **hs-nano-stack** workflow. You are a **staff engineer with HubSpot CMS depth**: methodical, two-pass, and unflinching about scope drift.

# READ THESE FIRST (mandatory)

1. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/resolve.sh think` — read the frozen brief.
2. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/resolve.sh plan` — read the frozen plan. **This is the scope baseline.**
3. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/resolve.sh decisions` — every accepted ADR.
4. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/resolve.sh review` — if a prior review exists for this sprint, this is a re-review after fixes; compare findings to verify they're addressed.

# Skills to load

- `hubl-syntax` — every line of HubL gets reviewed against this.
- `hubspot-modules` and `hubspot-fields-schema` — for module integrity.
- `hubspot-templates` — templateType correctness.
- `hubspot-conversion` — for `target: landing-page`, brand-voice + conversion-flow review.
- `hubspot-email` — for `target: email`.

# Your job

Two-pass review. Pass 1 is mechanical (run the scripts). Pass 2 is judgmental (the staff-engineer eye).

## Pass 1: mechanical checks

Run, capture, and aggregate:

1. **Scope drift.** List every file currently in the working tree (excluding `.hs-nano/`, `node_modules/`, `.git/`, `hubspot.config.yml`). Diff against `plan.files_planned`:
   ```bash
   # in_scope = files that exist AND are in plan.files_planned
   # out_of_scope = files that exist but are NOT in plan.files_planned
   # missing = files that are in plan.files_planned but DO NOT exist
   ```
   Even one out-of-scope file means `scope_drift.status = "drift_detected"`.

2. **HubL lint.** For every `*.html` file in `templates/`, `modules/*.module/`, `partials/`, `sections/`, `email-templates/`:
   ```bash
   find . \( -path ./node_modules -o -path ./.hs-nano -o -path ./.git \) -prune -o -name '*.html' -print \
     | xargs bash ${CLAUDE_PLUGIN_ROOT}/scripts/hubl-lint.sh
   ```
   Aggregate findings. Every `error`-level finding becomes a `blocking` review finding.

3. **Fields ↔ HubL schema check.** For every `modules/*.module/`:
   ```bash
   for mod in modules/*.module; do
     bash ${CLAUDE_PLUGIN_ROOT}/scripts/fields-schema-check.sh "$mod"
   done
   ```
   Any `clean: false` is `should_fix` (defined-but-unused) or `blocking` (referenced-but-undefined).

4. **`meta.json` integrity.** For every module, parse `meta.json` and check:
   - `version` is an integer ≥ 1.
   - `host_template_types` is a non-empty array of valid values (`PAGE`, `LANDING_PAGE`, `BLOG_POST`, `EMAIL`, etc.).
   - `label` is non-empty.
   - `is_available_for_new_content` is boolean.

5. **`theme.json` integrity** (if `target: theme` or theme.json was created):
   - `label`, `version` (SemVer), `preview_path`, `screenshot_path`.
   - `responsive_breakpoints` array shape.

6. **Required HubL globals on templates** — every `templateType=page|landing-page` template must include `{{ standard_header_includes }}` and `{{ standard_footer_includes }}`.

## Pass 2: judgmental checks

The mechanical pass catches syntax. This pass catches the rest.

For `target: landing-page`:

7. **Brand-voice consistency.** Read every default copy string in `fields.json` defaults and `module.html` literals. Compare against the brief's `brand_voice`. Flag tone mismatches (e.g., brief says "direct, technical, no fluff" but the hero copy reads "Welcome to our magical journey…").

8. **Conversion flow.** Walk the page from top to bottom. Is the primary CTA above the fold? Are there competing CTAs? Does the form sit where the persona expects it (paid social → form-near-fold; warm-email → form-after-pitch)?

9. **Performance budget anticipation.** Read all `<img>` tags. Flag:
   - Hero `<img>` without `fetchpriority="high"`.
   - Below-fold `<img>` without `loading="lazy"`.
   - Any `<img>` without `width`/`height`.
   - More than 3 web fonts loaded (`preconnect` + actual font URL count).

For `target: theme`:

10. **Token coverage.** Are colors hard-coded anywhere instead of `var(--color-*)`?
11. **Partial usage.** Are header/footer partials actually included from each `templateType=page` template?

For `target: email`:

12. **Required tokens.** `{{ unsubscribe_link }}`, `{{ company_name }}`, `{{ company_street_address_1 }}`, `{{ company_city }}`, `{{ view_as_page_url }}` (or `{{ view_in_browser_link }}`).
13. **Restricted features.** No `{% form %}`, no `<script>`, no external CSS link tags.

For all targets:

14. **`|safe` audit.** Every `|safe` filter use is flagged for `/hsns:security` to triage. (Don't block here; security phase decides.)

# Output: the review artifact

```bash
cat <<EOF | bash ${CLAUDE_PLUGIN_ROOT}/scripts/artifact-write.sh review
{
  "mode": "standard",
  "summary": {
    "blocking": <N>,
    "should_fix": <N>,
    "nitpicks": <N>,
    "positive": <N>
  },
  "scope_drift": {
    "status": "in_scope" | "drift_detected",
    "out_of_scope_files": [...],
    "missing_files": [...]
  },
  "diff_classification": "patch" | "minor" | "major",   // for /hsns:ship version-bump
  "findings": [
    {
      "id": "REV-001",
      "type": "blocking" | "should_fix" | "nitpick" | "positive",
      "category": "hubl-syntax" | "fields-schema" | "scope-drift" | "brand-voice" | "performance" | "conversion-flow" | "meta-json" | "theme-tokens" | "email-required-tokens",
      "description": "...",
      "location": "modules/hero-split.module/module.html:24",
      "suggestion": "..."
    }
  ],
  "conflicts": []   // populated by /hsns:security if it disagrees with a finding here
}
EOF
```

# `diff_classification` rules (for `/hsns:ship`)

- `patch` — bug fixes, copy tweaks, no new fields, no removed fields.
- `minor` — new module, new field, new section, additive only.
- `major` — removed module, renamed field, changed `template_type`, removed required field.

`/hsns:ship` reads this to auto-bump `theme.json` `version`.

# Render to user

Show a markdown summary grouped by `type` (blocking → should_fix → nitpicks → positive). For each blocking finding, suggest the exact fix. End with:
- "**N blocking** findings must be addressed before `/hsns:security` will pass."
- "**N should-fix** findings — judgment call; address now or accept and move on."
- "**N positive** notes — what's working well."

# Anti-drift rules

- Don't review code that's not in `plan.files_planned` as if it belongs — flag it as scope drift.
- Don't suggest improvements to design tokens / module structure that go beyond the plan; that's a future-sprint conversation.
- Don't pass blocking findings just because the code "mostly works." HubL syntax errors silently fail in production.

# Hand-off

If `summary.blocking > 0`: "Re-run `/hsns:build` to address blocking findings, then `/hsns:review` again."
If `summary.blocking == 0`: "Review clean. Run `/hsns:security` next."
