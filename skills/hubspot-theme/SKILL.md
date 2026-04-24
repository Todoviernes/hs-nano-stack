---
name: HubSpot Theme Structure
description: Use when scaffolding, reviewing, or modifying a HubSpot CMS Hub theme. Covers `theme.json`, `fields.json`, the canonical directory layout, child themes, and global partials.
version: 1.0.0
---

# HubSpot Theme Structure

A HubSpot CMS Hub theme is a directory that contains everything a portal needs to render a website: templates, modules, sections, partials, CSS, JS, images, and the metadata that wires it together.

## Canonical layout

```
my-theme/
├── theme.json                # required: theme metadata + setting groups
├── fields.json               # required: theme-wide editable fields (colors, fonts, etc.)
├── thumbnail.png             # required for marketplace; recommended otherwise
├── images/
│   └── ...                   # static assets shipped with the theme
├── css/
│   ├── main.css              # imported by the theme's master stylesheet
│   └── ...
├── js/
│   └── main.js
├── templates/
│   ├── page.html             # templateType=page
│   ├── landing.html          # templateType=landing-page
│   ├── system/
│   │   ├── error-page.html
│   │   ├── password-prompt.html
│   │   └── search-results.html
│   └── blog/
│       ├── blog-listing.html
│       └── blog-post.html
├── sections/                 # reusable drag-drop sections
│   ├── hero-section.html
│   └── ...
├── modules/
│   ├── hero-split.module/
│   │   ├── module.html
│   │   ├── fields.json
│   │   ├── meta.json
│   │   ├── module.css
│   │   └── module.js
│   └── ...
└── partials/                 # global partials (header, footer)
    ├── header.html
    └── footer.html
```

**Required at the theme root:** `theme.json`, `fields.json`, `thumbnail.png`. Everything else is conventional but `hs theme validate` will warn or block on missing pieces depending on marketplace rules.

## `theme.json` shape

```json
{
  "label": "My Theme",
  "preview_path": "./templates/landing.html",
  "screenshot_path": "./images/screenshot.png",
  "enable_domain_stylesheets": false,
  "version": "0.1.0",
  "license": "Apache-2.0",
  "responsive_breakpoints": [
    { "name": "mobile",  "mediaQuery": "(max-width: 767px)"  },
    { "name": "tablet",  "mediaQuery": "(min-width: 768px) and (max-width: 1023px)" },
    { "name": "desktop", "mediaQuery": "(min-width: 1024px)" }
  ]
}
```

**Key fields:**
- `label` — displayed in HubSpot's theme picker.
- `preview_path` — what the user sees in the theme preview iframe.
- `screenshot_path` — required for marketplace.
- `version` — SemVer; `/hsns:ship` auto-bumps based on review-artifact diff classification (see `docs/CONTRIBUTING.md`).
- `responsive_breakpoints` — feeds the responsive picker in the editor for image/spacing fields.

## `fields.json` (theme-wide)

Theme-level fields are the global design tokens. Modules and templates can read them via `{{ theme.<group>.<name> }}`.

```json
[
  {
    "name": "colors",
    "label": "Colors",
    "type": "group",
    "children": [
      { "name": "primary",   "label": "Primary",   "type": "color", "default": { "color": "#0F172A", "opacity": 100 } },
      { "name": "secondary", "label": "Secondary", "type": "color", "default": { "color": "#3B82F6", "opacity": 100 } },
      { "name": "text",      "label": "Body text", "type": "color", "default": { "color": "#0F172A", "opacity": 100 } }
    ]
  },
  {
    "name": "typography",
    "label": "Typography",
    "type": "group",
    "children": [
      { "name": "heading", "label": "Heading", "type": "font", "default": { "font": "Inter", "font_set": "GOOGLE", "size_unit": "px" } },
      { "name": "body",    "label": "Body",    "type": "font", "default": { "font": "Inter", "font_set": "GOOGLE", "size_unit": "px" } }
    ]
  },
  { "name": "max_width", "label": "Max content width (px)", "type": "number", "default": 1200 }
]
```

Theme fields drive **CSS variables**: in `css/main.css`, expose them as

```css
:root {
  --color-primary: {{ theme.colors.primary.color }};
  --color-secondary: {{ theme.colors.secondary.color }};
  --max-width: {{ theme.max_width }}px;
}
```

Modules then style with `var(--color-primary)`, never hard-coded hex.

## Child themes

A child theme inherits everything from a parent and overrides selectively.

```json
// child-theme/theme.json
{
  "label": "My Brand Theme",
  "extends": "@hubspot/cms-theme-boilerplate",
  "version": "0.1.0"
}
```

Files in the child theme override files in the parent at the same path. Use child themes for portal-specific brand variants without forking the whole parent.

## Global partials

Headers, footers, and other elements that should look identical across every page live as partials and get included with `{% global_partial %}`:

```hubl
{# partials/header.html #}
<header class="site-header">
  <a href="/" class="site-header__logo">
    {% if theme.logo.src %}
      <img src="{{ theme.logo.src }}" alt="{{ theme.logo.alt }}">
    {% else %}
      {{ site_settings.companyName }}
    {% endif %}
  </a>
  {% menu name="primary_navigation" tree_type="static" %}
</header>
```

```hubl
{# templates/page.html #}
{% global_partial path="../partials/header.html" %}
{% dnd_area "main_content" %}{% end_dnd_area %}
{% global_partial path="../partials/footer.html" %}
```

A global partial's content can be edited once in HubSpot's UI and propagates everywhere.

## Drag-drop areas (`dnd_area`)

Drag-drop areas only work in `templateType=page` or `landing-page` templates (not blog post or email). They give content editors a layout canvas at edit time.

```hubl
<!--
  templateType: landing-page
  label: Demo lead capture
-->
{% global_partial path="../partials/header.html" %}
{% dnd_area "main_content" %}
  {% dnd_section vertical_alignment="MIDDLE" background_color="#0F172A" %}
    {% dnd_column %}
      {% dnd_row %}
        {% dnd_module path="../modules/hero-split.module" %}
      {% end_dnd_row %}
    {% end_dnd_column %}
  {% end_dnd_section %}
{% end_dnd_area %}
{% global_partial path="../partials/footer.html" %}
```

The HubSpot editor renders this as a section-by-section drag-drop canvas. Editors can rearrange, add new modules, change spacing — all without touching code.

## Sections (reusable layouts)

A "section" is a pre-composed dnd_section that editors can drop into any `dnd_area`. Sections live under `sections/` and become available in the section picker once uploaded.

```hubl
{# sections/hero-with-cta.html #}
{% dnd_section vertical_alignment="MIDDLE" background_color="#FFFFFF" padding={ top: 80, bottom: 80 } %}
  {% dnd_column %}
    {% dnd_module path="../modules/hero-split.module" %}
  {% end_dnd_column %}
{% end_dnd_section %}
```

## What `/hsns:nano` decides

When the plan artifact's `target` is `theme`, the nano plan must include:
- `theme_fields` — the list of theme-wide field groups (colors, typography, max_width, etc.).
- `templates_planned` — which `templateType`s to scaffold (page, landing, system, blog).
- `partials_planned` — typically `header.html`, `footer.html`.
- `sections_planned` — the reusable section starters.
- `modules_planned` — the modules to ship inside the theme.

`/hsns:build` then scaffolds all of the above from `reference/theme-starter/`, with theme fields wired through to CSS variables.
