---
name: HubSpot Modules
description: Use when authoring or reviewing HubSpot CMS modules (`*.module/` directories) — covers module.html, fields.json, meta.json, module.css, module.js, and how editors interact with the module in the page editor.
version: 1.0.0
---

# HubSpot Modules

A module is the smallest reusable unit of UI on HubSpot CMS. It's a directory ending in `.module` that contains everything a content editor needs to drop a piece of UI on a page and configure it without writing code.

## Required directory shape

```
hero-split.module/
├── module.html        # required — the HubL template
├── fields.json        # required — the editable fields shown to content editors
├── meta.json          # required — module metadata (name, types, version, host config)
├── module.css         # optional — module-scoped styles
├── module.js          # optional — module-scoped JavaScript (rare; performance cost)
└── icon.svg           # optional — shown in the module picker
```

The directory **must** end in `.module` for HubSpot to recognize it.

## `meta.json`

Module metadata. The `version` is an integer that bumps every time the module's HubL or fields change.

```json
{
  "label": "Hero — split layout",
  "css_assets": [],
  "external_js": [],
  "global": false,
  "help_text": "Two-column hero with headline, subhead, image, and CTA.",
  "host_template_types": ["PAGE", "LANDING_PAGE", "BLOG_POST"],
  "module_id": null,
  "is_available_for_new_content": true,
  "smart_type": "NOT_SMART",
  "type": "module",
  "version": 1,
  "tags": ["hero", "landing"]
}
```

**Important fields:**
- `label` — shown in the editor's module picker.
- `host_template_types` — `PAGE`, `LANDING_PAGE`, `BLOG_POST`, `BLOG_LISTING`, `EMAIL`, `SITE_HEADER`, `SITE_FOOTER`. **Email modules** must include only `EMAIL`; landing modules typically include `PAGE`, `LANDING_PAGE`.
- `global` — a global module is shared across the portal; editing one instance affects all. Default false; only true for header/footer-style content.
- `version` — bump on every meaningful change (HubL or `fields.json`); HubSpot uses this to track in-portal cache invalidation.
- `is_available_for_new_content` — `true` to show in the picker; `false` to hide (e.g., deprecated).

## `fields.json`

The schema for editor-facing fields. See `hubspot-fields-schema` skill for the full field-type catalog. Minimal shape:

```json
[
  { "name": "headline", "label": "Headline", "type": "text", "default": "Build with HubSpot", "required": true },
  { "name": "subhead",  "label": "Sub-headline", "type": "richtext", "default": "<p>Phase-gated AI workflow for CMS Hub.</p>" },
  { "name": "image", "label": "Image", "type": "image", "default": { "src": "", "alt": "" } },
  { "name": "cta", "label": "CTA", "type": "group", "children": [
      { "name": "label", "label": "Label", "type": "text", "default": "Get a demo" },
      { "name": "url",   "label": "URL",   "type": "url",  "default": { "href": "/demo", "type": "EXTERNAL" } }
  ]}
]
```

Every field referenced in `module.html` as `{{ module.<name> }}` must be defined here, and vice versa. `scripts/fields-schema-check.sh` enforces this and `/hsns:review` calls it.

## `module.html`

The HubL template. Receives `module.<field-name>` for every field, plus standard HubL globals.

```hubl
<section class="hero-split">
  <div class="hero-split__copy">
    <h1 class="hero-split__headline">{{ module.headline }}</h1>
    <div class="hero-split__subhead">{{ module.subhead }}</div>
    {% if module.cta.url.href %}
      <a class="hero-split__cta btn btn--primary"
         href="{{ module.cta.url.href|escape }}"
         {% if module.cta.url.type == "EXTERNAL" %}target="_blank" rel="noopener"{% endif %}>
        {{ module.cta.label }}
      </a>
    {% endif %}
  </div>
  {% if module.image.src %}
    <div class="hero-split__media">
      <img src="{{ module.image.src }}"
           alt="{{ module.image.alt }}"
           {% if module.image.width %}width="{{ module.image.width }}"{% endif %}
           {% if module.image.height %}height="{{ module.image.height }}"{% endif %}
           loading="lazy" decoding="async">
    </div>
  {% endif %}
</section>

{% require_css %}
  <style>{% include "./module.css" %}</style>
{% end_require_css %}
```

**Patterns to follow:**
- Always `|escape` URLs before placing them in `href`/`src` (defense in depth — HubL escapes by default, but be explicit).
- Wrap optional fields in `{% if %}` — HubL silently outputs empty strings, which can break HTML structure (e.g., `<a href="">` shows as a broken link).
- Use `loading="lazy" decoding="async"` on images below the fold; the hero image typically wants `loading="eager"` and `fetchpriority="high"`.
- Inline module CSS via `{% require_css %}` to keep concerns together; HubSpot deduplicates includes.

## `module.css`

Scope styles to the module's root class. Assume the same module may appear multiple times on one page.

```css
.hero-split {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 3rem;
  align-items: center;
  max-width: var(--max-width);
  margin-inline: auto;
  padding: 4rem 1.5rem;
}

.hero-split__headline {
  font-family: var(--font-heading);
  font-size: clamp(2rem, 5vw, 3.5rem);
  line-height: 1.1;
  color: var(--color-text);
  margin: 0 0 1rem;
}

.hero-split__cta {
  display: inline-block;
  padding: 0.875rem 1.5rem;
  background: var(--color-primary);
  color: white;
  text-decoration: none;
  border-radius: 0.5rem;
}

@media (max-width: 767px) {
  .hero-split { grid-template-columns: 1fr; gap: 2rem; padding-block: 2.5rem; }
}
```

**Rules:**
- Use CSS variables exposed by the theme (`var(--color-primary)`, `var(--max-width)`).
- Never hard-code colors or fonts — they should always come from `theme.json`.
- Use `clamp()` for fluid typography instead of multiple media-query font sizes.
- Mobile media query is mandatory; landing pages get >50% mobile traffic from paid social.

## `module.js`

Avoid unless you genuinely need interactivity beyond CSS. Most modules don't need JS.

If you do need it:
```js
(function () {
  const modules = document.querySelectorAll('.hero-split');
  modules.forEach((mod) => {
    // initialization
  });
})();
```

**Rules:**
- Wrap in IIFE — the editor previews multiple modules; global state leaks bite.
- No third-party fetches without explicit user opt-in (see `hubl-security` skill).
- No secrets, API keys, or tracking IDs in `module.js`. Editors can read this. Use environment-injected HubL or HubSpot Operations Hub for those.

## Module placement on a page

Three ways:

1. **Drag-and-drop area** — editors drop modules into `dnd_area` on a `page`/`landing-page` template (preferred for landings).
2. **`{% module %}` tag** — fixed module instance, configured at template-write time.
3. **Section embed** — a section pre-composes `dnd_module` calls; editors drop the section.

```hubl
{# Method 2: fixed instance, in a non-dnd template #}
{% module "hero" path="../modules/hero-split.module",
   headline="Welcome",
   image={ src: "/images/hero.jpg", alt: "Hero" },
   cta={ label: "Get started", url: { href: "/start", type: "EXTERNAL" } }
%}
```

## Versioning a module

Bump `meta.json` `"version"` (integer, +1) when:
- HubL changes shape (new field rendered, removed field, new wrapper element).
- `fields.json` adds, removes, or renames a field.

Don't bump for pure CSS or copy tweaks — HubSpot's portal cache picks those up automatically.

## What `/hsns:build` generates

For each `module_map` entry in the nano plan, `/hsns:build` creates:
- `modules/<name>.module/module.html`
- `modules/<name>.module/fields.json`
- `modules/<name>.module/meta.json` (version: 1)
- `modules/<name>.module/module.css`

It then runs `scripts/fields-schema-check.sh` on each to confirm `fields.json` ↔ `module.html` consistency before declaring the build done.
