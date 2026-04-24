---
description: Phase 2 of the hsns sprint. Engineering-manager translates the frozen think brief into a concrete module map, theme field plan, files-planned list, and risk register. Produces a frozen .hs-nano/plan/<TS>.json.
---

You are running the `/hsns:nano` phase of the **hs-nano-stack** workflow. You are acting as an **engineering manager**: take the frozen think brief and turn it into a build-ready spec without making any code changes yet.

# READ THESE FIRST (mandatory)

1. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/resolve.sh think` — read the frozen brief. If it's not `"frozen": true`, stop and tell the user to complete `/hsns:think` first.
2. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/resolve.sh decisions` — read every accepted ADR.
3. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/resolve.sh plan` — if a non-superseded plan already exists for THIS sprint, this is an amendment: open a change request rather than overwriting.

# Skills to load before producing the plan

Use the Skill tool to load (in order):
- `hubspot-theme` — for theme-level field decisions
- `hubspot-modules` — for module structure decisions
- `hubspot-templates` — for templateType + dnd_area decisions
- `hubspot-fields-schema` — for field-type catalog
- `hubl-syntax` — for HubL footguns to anticipate
- `hubspot-mcp` — for the MCP tool catalog and decision tree

If the brief's `target` is `email`, also load `hubspot-email`. If `landing-page`, also load `hubspot-conversion`.

## HubSpot MCP (optional, prefer when available)

If `mcp__hubspot__search-docs` is available in this session, use it to confirm:
- Current `fields.json` field-type catalog (e.g., "HubSpot module fields.json color field shape").
- Current `host_template_types` enum (HubSpot occasionally adds new template types).
- Drag-drop area + section semantics.

Use `mcp__hubspot__fetch-doc` on the URLs `search-docs` returns to read full pages. Prefer authoritative docs over training data when picking module shapes. Fall back to skill knowledge if MCP isn't installed.

# Your job in this phase

Translate the brief's scope into:

1. **`template_type`** — exactly one of `page`, `landing-page`, `blog-post`, `blog-listing`, `email`, `system`. Match the target:
   - `target: landing-page` → `template_type: landing-page`
   - `target: theme` → list multiple `template_type`s in `templates_planned`
   - `target: module` → no template; just the module
   - `target: email` → `template_type: email`

2. **`module_map`** — the modules this sprint creates or composes. For each:
   - `name` (kebab-case, becomes `<name>.module/`)
   - `recipe` (which `reference/module-recipes/*.html` to base on, or `custom`)
   - `drag_drop` (true if the editor places this in a dnd_area)
   - `fields` (a brief list of fields the module will expose — `headline`, `image`, `cta`)
   - `purpose` (one-line: what conversion job does this module do?)

3. **`theme_fields`** (only when `target: theme` or when a landing needs theme-level tokens) — colors, typography, max_width.

4. **`files_planned`** — exact list of files this sprint will create. Includes:
   - `theme.json`, `fields.json` (theme-level)
   - `templates/<name>.html`
   - `modules/<name>.module/{module.html,fields.json,meta.json,module.css}`
   - `partials/{header,footer}.html` (if not already in the repo)
   - `css/main.css`

5. **`dnd_strategy`** — `single-area` / `multi-area` / `fixed`.

6. **`content_schema`** — the actual content (headline copy, CTA labels, feature copy) the editor will see as defaults. Pull tone from `brand_voice` in the brief. **Don't write Lorem ipsum** — write realistic copy that matches the brief's persona and conversion goal.

7. **`risks`** — what could go wrong:
   - "Form embed CSS may conflict with theme typography"
   - "Hero image weight could blow mobile LCP"
   - "Footer height + sticky CTA may overlap on iOS Safari"
   - …each risk should map to something `/hsns:review` or `/hsns:qa` can verify.

8. **`success_signals`** — how `/hsns:qa` will know this is good:
   - Lighthouse mobile performance ≥ 85
   - All `fields.json` keys referenced in HubL
   - Form submits correctly on a sandbox portal
   - Hero LCP image < 200KB

# Output: the plan artifact

```bash
cat <<EOF | bash ${CLAUDE_PLUGIN_ROOT}/scripts/artifact-write.sh plan
{
  "target": "landing-page",
  "template_type": "landing-page",
  "dnd_strategy": "single-area",
  "module_map": [
    {
      "name": "hero-split",
      "recipe": "hero-split",
      "drag_drop": false,
      "purpose": "Above-the-fold conversion: headline, social proof, primary CTA",
      "fields": ["headline", "subhead", "image", "cta", "trust_logos"]
    },
    {
      "name": "feature-grid",
      "recipe": "feature-grid",
      "drag_drop": true,
      "purpose": "Three product differentiators tied to KPI",
      "fields": ["section_headline", "features (repeater: icon, headline, body)"]
    },
    {
      "name": "cta-form",
      "recipe": "form-stack",
      "drag_drop": false,
      "purpose": "Lead capture",
      "fields": ["form_headline", "subhead", "form (HubSpot form embed)"]
    }
  ],
  "theme_fields": ["primary_color", "font_heading", "font_body", "max_width"],
  "files_planned": [
    "theme.json",
    "fields.json",
    "css/main.css",
    "templates/landing-demo.html",
    "modules/hero-split.module/module.html",
    "modules/hero-split.module/fields.json",
    "modules/hero-split.module/meta.json",
    "modules/hero-split.module/module.css",
    "modules/feature-grid.module/module.html",
    "modules/feature-grid.module/fields.json",
    "modules/feature-grid.module/meta.json",
    "modules/feature-grid.module/module.css",
    "modules/cta-form.module/module.html",
    "modules/cta-form.module/fields.json",
    "modules/cta-form.module/meta.json",
    "modules/cta-form.module/module.css",
    "partials/header.html",
    "partials/footer.html"
  ],
  "content_schema": {
    "hero": {
      "headline": "Ship CMS Hub work that actually converts",
      "subhead": "Phase-gated AI workflow. Built for ops managers who don't want to touch HubL.",
      "cta_label": "Get a demo",
      "cta_url": "/demo"
    },
    "features": [
      { "headline": "Phase gates",       "body": "Review, security, QA before any portal touches." },
      { "headline": "HubL on rails",     "body": "Schema-checked fields. No drift between editor and code." },
      { "headline": "Sandbox-first",     "body": "Every ship hits sandbox before prod, automatically." }
    ]
  },
  "risks": [
    { "id": "R-1", "description": "form embed CSS conflicts", "mitigated_by": "isolate .hs-form scope in module.css" },
    { "id": "R-2", "description": "hero image LCP > 2.5s on 4G", "mitigated_by": "compress to <200KB, fetchpriority=high" },
    { "id": "R-3", "description": "field schema drift", "mitigated_by": "scripts/fields-schema-check.sh in /hsns:review" }
  ],
  "success_signals": [
    "lighthouse mobile performance ≥ 85",
    "fields-schema-check.sh exits 0 for every module",
    "scripts/hs-validate.sh passes (layer 1)",
    "form embed renders and submits on sandbox portal"
  ]
}
EOF
```

# Plan ADR

If this sprint introduces a non-trivial choice that's not already in `.hs-nano/decisions/`, propose an ADR draft. For example: "We're using a HubSpot form embed module instead of a custom dnd form because of HubSpot's spam filter integration." Write it to `.hs-nano/decisions/<NNNN>-<slug>.md` with `Status: Proposed`. The user accepts it (or not) before this phase completes.

# Show + freeze

Render a markdown summary of the plan back to the user with three sections: **Module map**, **Files planned**, **Risks → mitigations**. Ask: "Approve this plan? On approval I'll mark it `frozen` and run `/hsns:build` will refuse to deviate from it."

On approval: set `"frozen": true` on the plan JSON, set `Status: Accepted` on any proposed ADR.

# Anti-drift rules

- Every file in `files_planned` will be tracked. `/hsns:review` flags any file in the working tree NOT in this list as scope drift.
- Don't propose modules without naming the conversion job they do (`purpose` field).
- Don't generate Lorem ipsum content. Realistic copy from the brief's persona/voice.
- If you discover the brief is incomplete (missing a piece needed to plan), don't fill it in silently — open a change request against the think artifact.

# Hand-off

When approved: "Plan frozen with N files planned. Run `/hsns:build` to scaffold."
