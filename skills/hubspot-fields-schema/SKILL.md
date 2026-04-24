---
name: HubSpot Fields Schema
description: Use when writing or reviewing `fields.json` for a module or theme. Covers every field type, its default shape, common gotchas, and how the field comes through to HubL.
version: 1.0.0
---

# HubSpot Fields Schema (`fields.json`)

`fields.json` defines what a content editor can configure on a module or theme. It is an array of field objects, with optional `group` fields that nest children. Every key listed here is referenceable in HubL as `{{ module.<name> }}` (modules) or `{{ theme.<group>.<name> }}` (theme).

## Common field properties (apply to all types)

```json
{
  "name": "headline",                    // required — referenced in HubL
  "label": "Headline",                   // required — shown to editor
  "type": "text",                        // required
  "default": "Build with HubSpot",       // recommended
  "required": false,                     // default false
  "locked": false,                       // hide from editors who lack permission
  "help_text": "Shown above the subhead.", // optional tooltip
  "inline_help_text": null,              // optional secondary hint
  "visibility": null                     // conditional show/hide based on another field
}
```

**`visibility`** — show this field only when another field has a specific value:
```json
{
  "name": "secondary_cta_label",
  "type": "text",
  "default": "",
  "visibility": {
    "controlling_field": "show_secondary_cta",
    "controlling_value_regex": "true",
    "operator": "EQUAL"
  }
}
```

## Field-type catalog

### `text` — single-line text

```json
{ "name": "headline", "type": "text", "default": "Welcome" }
```
HubL: `{{ module.headline }}` — auto-escaped string.

### `richtext` — WYSIWYG HTML

```json
{ "name": "subhead", "type": "richtext", "default": "<p>Phase-gated workflow.</p>" }
```
HubL: `{{ module.subhead }}` — raw HTML, do **not** apply `|safe`. To get plaintext use `|striptags`.

### `image` — image picker

```json
{ "name": "image", "type": "image", "default": { "src": "", "alt": "" } }
```
HubL: `{{ module.image.src }}`, `{{ module.image.alt }}`, `{{ module.image.width }}`, `{{ module.image.height }}`.

Best practice: set `responsive_options` to enable `srcset`/`sizes` automatically:
```json
{
  "name": "hero_image",
  "type": "image",
  "default": { "src": "", "alt": "" },
  "responsive": true,
  "show_loading": true
}
```

### `url` — link picker (external, internal page, file, blog post, email)

```json
{
  "name": "cta_url",
  "type": "url",
  "default": { "href": "/demo", "type": "EXTERNAL" },
  "supported_types": ["EXTERNAL", "CONTENT", "FILE", "EMAIL_ADDRESS", "BLOG", "CALL_TO_ACTION", "PAYMENT"]
}
```
HubL: `{{ module.cta_url.href }}`, `{{ module.cta_url.type }}`. Always `|escape` before injecting into `href`.

### `link` — alias of url with extra props (rel, target)

```json
{ "name": "external_link", "type": "link", "default": { "url": { "href": "https://example.com", "type": "EXTERNAL" }, "open_in_new_tab": true, "no_follow": false, "sponsored": false, "user_generated_content": false }}
```

### `boolean` — toggle

```json
{ "name": "show_cta", "type": "boolean", "default": true }
```
HubL: `{% if module.show_cta %}` — note: HubSpot may stringify; `{% if module.show_cta == true %}` is safer in some contexts.

### `number` — numeric input

```json
{ "name": "max_features", "type": "number", "default": 6, "min": 1, "max": 12, "step": 1, "suffix": " items" }
```
HubL: `{{ module.max_features }}` or `{{ module.max_features|int }}` for safety.

### `choice` — dropdown / radio

```json
{
  "name": "alignment",
  "type": "choice",
  "choices": [
    ["left", "Left"],
    ["center", "Center"],
    ["right", "Right"]
  ],
  "default": "left",
  "display": "select"
}
```
HubL: `{{ module.alignment }}` returns the *value* (first element of each tuple).

### `color` — color picker

```json
{
  "name": "background",
  "type": "color",
  "default": { "color": "#FFFFFF", "opacity": 100 },
  "show_opacity": true
}
```
HubL: `{{ module.background.color }}`, `{{ module.background.opacity }}`. Compose into CSS:
```hubl
<section style="background-color: {{ module.background.color }};">
```

### `font` — font picker

```json
{
  "name": "heading_font",
  "type": "font",
  "default": { "font": "Inter", "font_set": "GOOGLE", "size": 32, "size_unit": "px", "color": "#0F172A", "styles": { "font-weight": "700" } }
}
```
Read all the parts when applying:
```hubl
<style>
  .hero__h1 {
    font-family: {{ module.heading_font.font }}, sans-serif;
    font-size: {{ module.heading_font.size }}{{ module.heading_font.size_unit }};
    color: {{ module.heading_font.color }};
    font-weight: {{ module.heading_font.styles['font-weight'] }};
  }
</style>
```

### `icon` — HubSpot icon picker

```json
{ "name": "feature_icon", "type": "icon", "default": { "name": "rocket", "type": "SOLID", "unicode": "f135" } }
```

### `tag` — HubSpot blog tag picker

```json
{ "name": "selected_tag", "type": "tag", "default": null, "tag_value": "SLUG" }
```

### `simplemenu` / `menu` — site menu

```json
{ "name": "primary_nav", "type": "menu", "default": null }
```
HubL: `{% menu name="primary_nav" tree_type="static" %}` (use the `name` attribute set by the editor).

### `cta` — Call-to-Action embed

```json
{ "name": "cta", "type": "cta", "default": null }
```
HubL: `{% cta guid="{{ module.cta }}" %}`.

### `form` — HubSpot form embed

```json
{ "name": "lead_form", "type": "form", "default": { "form_id": "", "response_type": "redirect", "redirect_url": "/thanks", "message": "Thanks!" } }
```
HubL:
```hubl
{% form
   form_to_use="{{ module.lead_form.form_id }}"
   response_response_type="{{ module.lead_form.response_type }}"
   response_redirect_url="{{ module.lead_form.redirect_url }}"
   response_message="{{ module.lead_form.message }}"
%}
```

### `group` — nested fields

```json
{
  "name": "cta",
  "label": "CTA",
  "type": "group",
  "expanded": true,
  "children": [
    { "name": "label", "type": "text", "default": "Get a demo" },
    { "name": "url",   "type": "url",  "default": { "href": "/demo", "type": "EXTERNAL" } }
  ]
}
```
HubL: `{{ module.cta.label }}`, `{{ module.cta.url.href }}`.

### `repeater` — list of repeating fields (e.g., feature cards)

Wrap a `group` with `occurrence`:
```json
{
  "name": "features",
  "label": "Features",
  "type": "group",
  "occurrence": { "min": 0, "max": 12, "default": 3, "sorting_label_field": "headline" },
  "children": [
    { "name": "icon", "type": "icon" },
    { "name": "headline", "type": "text", "default": "Fast" },
    { "name": "description", "type": "richtext", "default": "<p>Built for speed.</p>" }
  ]
}
```
HubL:
```hubl
{% for feature in module.features %}
  <article class="feature">
    {% if feature.icon.name %}<i class="fas fa-{{ feature.icon.name }}"></i>{% endif %}
    <h3>{{ feature.headline }}</h3>
    <div class="feature__desc">{{ feature.description }}</div>
  </article>
{% endfor %}
```

### `embed` — third-party embed (YouTube, oembed, etc.)

```json
{ "name": "video", "type": "embed", "default": { "source_type": "oembed", "oembed_url": "" } }
```

## Required-field rules

`required: true` enforces the field at edit time. Use it for:
- Fields that, if empty, break the layout (`headline`, `image.src` for a hero with no fallback).
- Form GUIDs (HubL renders nothing without a valid form_to_use).

Don't make a field `required` if you have a sensible empty-state branch with `{% if %}`.

## Default-value discipline

Defaults are **shipped** to every new instance of the module. They should be:
- Realistic placeholders that show what the module looks like populated, not "Lorem ipsum."
- Empty for media (`{ "src": "", "alt": "" }`) — defaults to a real image lock you in.
- The most common pick for `choice` fields.

## Theme-level vs module-level fields

| | Theme `fields.json` | Module `fields.json` |
|---|---|---|
| Scope | global to the theme | per module instance |
| Read in HubL | `{{ theme.<group>.<name> }}` | `{{ module.<name> }}` |
| Edited in | Theme settings | Page editor (per instance) |
| Use for | brand tokens (colors, fonts, max-width) | content (headline, image, CTA) |

If a value should be the same on every page (brand color), put it in **theme** fields. If it varies per page (hero copy), put it in **module** fields.

## Validation

Every module's `fields.json` is checked against its `module.html` by `scripts/fields-schema-check.sh`:
- **Defined-but-unused** keys (in `fields.json`, not in HubL) → warning.
- **Referenced-but-undefined** keys (in HubL, not in `fields.json`) → error; build fails.

The `/hsns:review` phase calls this script for every module in `module_map` and rolls findings into the review artifact.
