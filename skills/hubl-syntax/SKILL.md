---
name: HubL Syntax
description: Use when writing or reviewing HubL (HubSpot Markup Language) — Jinjava-based templating used in CMS Hub themes, modules, landing pages, and email templates. Covers tags, expressions, filters, control flow, and the most common syntax footguns.
version: 1.0.0
---

# HubL Syntax

HubL is HubSpot's templating language. It is a fork of Jinjava (which itself is a JVM port of Jinja2). It compiles to HTML server-side inside HubSpot's CMS — the agent never gets to execute HubL locally; we ship it and HubSpot renders.

## Three delimiter shapes (memorize)

| Delimiter | Use | Example |
|---|---|---|
| `{{ ... }}` | **Expression** — outputs a value | `{{ module.headline }}` |
| `{% ... %}` | **Statement / tag** — control flow, assignment | `{% if module.show_button %} ... {% endif %}` |
| `{# ... #}` | **Comment** — stripped from output | `{# debug: hero values #}` |

Mixing these up is the #1 syntax error. Output → `{{ }}`. Logic → `{% %}`. Notes → `{# #}`.

## Variables and dotted access

- `{{ module.headline }}` — a field defined in `fields.json`.
- `{{ content.absolute_url }}` — page-level content variable.
- `{{ request.query_dict.utm_campaign }}` — request data.
- `{{ widget.stylesheet_url }}` — used inside email modules.
- `{{ theme.colors.primary }}` — theme-level fields.

If a variable is undefined, HubL outputs an empty string. There is no `null` literal — use `if my_var` to check truthiness.

## Filters (pipe syntax)

Apply transformations with `|`. Filters chain.

```hubl
{{ module.title | upper }}
{{ module.body  | truncate(160) }}
{{ post.publish_date | datetimeformat('%B %e, %Y') }}
{{ module.headline | escape }}
{{ url | urlencode }}
```

**Common safe-by-default filters** (use these on user-editable fields):
- `escape` (alias `e`) — HTML-escape; HubL applies this automatically to most output.
- `truncate(N)` — cut at word boundary, append `...`.
- `striptags` — remove all HTML tags.
- `urlencode` — for URL parameters.

**Dangerous filter:**
- `safe` — opt out of auto-escaping. Renders raw HTML. **Never** apply to a field a content editor can change unless you control the entire HTML pipeline. This is the #1 HubL XSS vector.

## Control flow

```hubl
{% if module.cta_url %}
  <a href="{{ module.cta_url|escape }}">{{ module.cta_label }}</a>
{% elif module.show_default_cta %}
  <a href="/contact">Contact us</a>
{% endif %}

{% for feature in module.features %}
  <li>{{ loop.index }}. {{ feature.headline }}</li>
{% endfor %}

{% set max_items = 6 %}
```

**Loop variables:** `loop.index` (1-based), `loop.index0` (0-based), `loop.first`, `loop.last`, `loop.length`.

## Macros

Reusable snippets with parameters.

```hubl
{% macro button(label, url, style='primary') %}
  <a class="btn btn--{{ style }}" href="{{ url|escape }}">{{ label }}</a>
{% endmacro %}

{{ button('Get a demo', module.cta_url) }}
```

## Includes & template inheritance

```hubl
{# include a partial — path is portal-relative #}
{% include "../../partials/header.html" %}

{# extend a parent template, override blocks #}
{% extends "../../layouts/base.html" %}
{% block main_content %}
  ...
{% endblock %}
```

Use `extends + block` for layout inheritance, `include` for stateless partials.

## HubSpot-specific tags

These are **not** in vanilla Jinja — they're HubSpot extensions.

```hubl
{# A drag-drop area on a template — only valid in templateType=page or landing-page. #}
{% dnd_area "main_content" %}
  {% dnd_section %}
    {% dnd_column %}
      {% dnd_module path="../modules/hero-split.module" %}
    {% end_dnd_column %}
  {% end_dnd_section %}
{% end_dnd_area %}

{# Module instance — drops a module on a non-dnd template. #}
{% module "hero" path="../modules/hero-split.module",
   headline="Build with HubSpot", subhead="Phase-gated workflow." %}

{# A Form (HubSpot's form embed). #}
{% form
   form_to_use="<form-guid>"
   response_response_type="redirect"
   response_redirect_url="/thanks"
%}

{# Global partial — share content across pages. #}
{% global_partial path="../partials/global-header.html" %}
```

Each of these has a `meta.json` impact: drag-drop areas + module instances are recognized by the HubSpot CMS UI; mistype the tag and the page renders blank.

## Common syntax footguns

1. **`{{ }}` on a missing variable.** Renders empty silently. Use `{% if module.headline %}` first if presence matters.
2. **`|safe` on rich-text fields.** Editors can paste arbitrary HTML/JS — XSS. Strip with `striptags` instead, or trust HubL's default escape.
3. **Newlines inside `{{ ... }}`.** Allowed by Jinja, but historically buggy in Jinjava. Keep expressions on one line.
4. **`{% set x = ... %}` scoping.** A `set` inside an `{% if %}` block is scoped to that block. Use `{% set x = '' %}{% if ... %}{% set x = ... %}{% endif %}{{ x }}` instead.
5. **`for` over a missing list.** Doesn't error — silently iterates zero times. Wrap with `{% if module.items|length > 0 %}` if you need an empty state.
6. **`include` paths.** Paths are portal-relative (the theme root inside HubSpot Design Manager). Local file-system paths inside your repo only work if your repo structure matches the portal structure.
7. **Comparing strings to numbers.** `{% if module.count == "3" %}` — the form fields return strings. Cast: `{% if module.count|int == 3 %}`.
8. **Booleans in `fields.json`.** A boolean field comes through as a string `"true"`/`"false"` in some contexts; cast or compare carefully.
9. **`{{ theme.foo }}` vs `{{ module.foo }}`.** Theme fields vs per-instance fields. Don't reference `module.x` from a non-module template.
10. **Email-only restrictions.** No `{% form %}`, no `<script>`, restricted CSS. See `hubspot-email` skill.

## Quick reference

For a full filter / tag catalog: `reference/hubl-cheatsheet.md`.
For HubSpot's official docs (always more recent): https://developers.hubspot.com/docs/cms/hubl

## When to escape, when not to

| Field type | Auto-escaped? | Action |
|---|---|---|
| `text` | yes | safe to use `{{ module.x }}` |
| `richtext` | no (already HTML) | trust HubSpot's editor sanitization, or `\|striptags` for plaintext |
| `url` | yes | always `\|escape` again before insertion in `href`/`src` for defense-in-depth |
| `image.src` | yes | safe |
| `link.url` | yes | safe |
| `number`, `boolean`, `choice`, `tag` | yes | safe; cast as needed |

Default rule: **never** use `|safe` unless you've reasoned about why; if you do, drop a `{# safe-justified: <reason> #}` comment so `/hsns:security` knows it was deliberate.
