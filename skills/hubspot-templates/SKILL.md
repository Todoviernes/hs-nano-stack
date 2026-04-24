---
name: HubSpot Templates
description: Use when authoring or reviewing HubSpot CMS templates (page, landing-page, blog, system, email). Covers the templateType annotation, dnd_area placement, partial includes, and which globals are available per template type.
version: 1.0.0
---

# HubSpot Templates

A template is the top-level HTML file a page is rendered from. Every template must declare its **templateType** in an HTML comment at the top — this tells HubSpot how to treat it (which fields to inject, which dnd tags are allowed, where it appears in the create-content picker).

## Template type annotations

Always at the **first non-blank line** of the file. HubSpot parses this comment to register the template.

```hubl
<!--
  templateType: landing-page
  label: Lead capture — split layout
  screenshotPath: ./screenshots/lead-capture.png
  isAvailableForNewContent: true
-->
<!DOCTYPE html>
<html lang="{{ html_lang }}" {% if is_listing_view %}data-listing="true"{% endif %}>
...
```

**Recognized values for `templateType`:**

| `templateType` | Use | Allows `dnd_area`? | Notes |
|---|---|---|---|
| `page` | A standard site page | yes | Most common; supports global partials, dnd, and `{% module %}` instances |
| `landing-page` | A landing page (separate URL pattern, separate analytics) | yes | Conversion-focused; HubSpot's editor exposes campaign/source fields |
| `blog-post` | A single blog post | no | Wraps `{{ content.post_body }}`; no dnd |
| `blog-listing` | The blog index page | no | Iterates `{% for content in contents %}` |
| `email` | A marketing/transactional email | no | Restricted: no `{% form %}`, no `<script>`, restricted CSS |
| `system` | error pages, password prompt, search results | no | Special routes: `/_hcms/error/error-page`, etc. |
| `none` (no annotation) | A partial or include | n/a | Not selectable as a content template |

## Required HubL globals per page

These are injected by HubSpot at render time. You can read them from any template.

```hubl
<!doctype html>
<html lang="{{ html_lang }}">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{{ content.html_title }}</title>
  <meta name="description" content="{{ content.meta_description }}">
  {{ standard_header_includes }}   {# HubSpot-injected scripts, analytics, etc. #}
</head>
<body class="hs-page">
  ...
  {{ standard_footer_includes }}   {# HubSpot footer scripts #}
</body>
</html>
```

**`standard_header_includes`** — required on all pages. It injects HubSpot's analytics, CTA tracker, and forms script. Without it, HubSpot's tracking and forms won't work.

**`standard_footer_includes`** — required at the closing `</body>` on every page. Without it, deferred scripts and JS-based widgets fail.

## Drag-drop area patterns

Drag-drop areas (`dnd_area`) are only valid in `templateType=page` and `templateType=landing-page`.

**Single dnd_area** (typical for a landing page):
```hubl
{% global_partial path="../partials/header.html" %}

{% dnd_area "main_content"
   class="page-main"
%}
  {% dnd_section padding={ top: 80, bottom: 80 } %}
    {% dnd_column %}
      {% dnd_module path="../modules/hero-split.module" %}
    {% end_dnd_column %}
  {% end_dnd_section %}

  {% dnd_section padding={ top: 60, bottom: 60 } background_color="#F8FAFC" %}
    {% dnd_column %}
      {% dnd_module path="../modules/feature-grid.module" %}
    {% end_dnd_column %}
  {% end_dnd_section %}
{% end_dnd_area %}

{% global_partial path="../partials/footer.html" %}
```

**Multiple dnd_areas** (a sidebar layout, for example):
```hubl
{% dnd_area "main_content"   %}{% end_dnd_area %}
{% dnd_area "sidebar_content" %}{% end_dnd_area %}
```

Each `dnd_area` needs a unique name. Editors get a separate canvas per area.

## Non-dnd page (fixed module instances)

When the layout shouldn't be editable, drop modules with `{% module %}`:

```hubl
<!--
  templateType: page
  label: Pricing — fixed layout
-->
<!doctype html>
<html lang="{{ html_lang }}">
<head>...{{ standard_header_includes }}</head>
<body>
  {% global_partial path="../partials/header.html" %}

  <main class="page-pricing">
    {% module "hero" path="../modules/hero-split.module",
       headline="Pricing",
       subhead="Simple, transparent." %}
    {% module "table" path="../modules/pricing-table.module" %}
  </main>

  {% global_partial path="../partials/footer.html" %}
  {{ standard_footer_includes }}
</body>
</html>
```

Editors can still tweak the `module.html` defaults via the in-page editor (per-instance), but they can't add or remove modules without the developer.

## Email templates

Email templates have their own `templateType=email` and obey *very* different rules. See `hubspot-email` skill for the full set; the short version:

- No `{% form %}` (use a CTA link to a landing page form).
- No `<script>` (most clients strip it anyway).
- No external CSS — inline styles or `<style>` in `<head>`.
- Required tokens: `{{ unsubscribe_link }}`, `{{ company_name }}`, `{{ company_street_address_1 }}`, `{{ company_city }}`, `{{ view_as_page_url }}` (or `{{ view_in_browser_link }}`).

Skipping any required token causes `scripts/hs-validate.sh (layer 1) + portal-side checks` to error or HubSpot to refuse to send.

## System templates

System templates handle special URLs the portal needs:

- `templates/system/error-page.html` (404, 500)
- `templates/system/password-prompt.html` (password-protected pages)
- `templates/system/email-subscription-preferences.html`
- `templates/system/email-subscriptions-confirmation.html`
- `templates/system/search-results.html`

They use `templateType=system` (or no annotation). Each has special HubL globals (e.g., `email_subscriptions` on the preferences page).

## Blog templates

```hubl
<!--
  templateType: blog-post
  label: Blog post — long form
-->
<!doctype html>
<html lang="{{ html_lang }}">
<head>...{{ standard_header_includes }}</head>
<body>
  <article class="post">
    <header class="post__header">
      <h1>{{ content.name }}</h1>
      <p class="post__meta">
        {{ content.publish_date | datetimeformat('%B %e, %Y') }} · {{ content.blog_post_author.full_name }}
      </p>
    </header>
    <div class="post__body">
      {{ content.post_body }}
    </div>
  </article>
  {{ standard_footer_includes }}
</body>
</html>
```

Blog post body comes from `{{ content.post_body }}` (already-sanitized HTML). Don't `|safe` it (it's already trusted), don't `|escape` it (it's HTML).

## What `/hsns:nano` decides for templates

When `target` is `landing-page` or `theme`, the nano plan must specify:
- `template_type` — exactly which annotation value.
- `dnd_strategy` — `single-area` (one big editable canvas), `multi-area` (e.g., sidebar+main), or `fixed` (no dnd).
- `globals_used` — which `standard_header_includes`-style globals are wired up.
- `partials_referenced` — header/footer global partials.

`/hsns:build` then writes the template with the correct annotation, the right dnd structure, and references to the modules from `module_map`.
