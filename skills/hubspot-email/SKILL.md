---
name: HubSpot Email Templates
description: Use when authoring or reviewing HubSpot email templates (templateType=email). Covers required tokens, restricted CSS, no-JS rule, mobile responsive patterns, dark mode, and email-client compatibility gotchas.
version: 1.0.0
---

# HubSpot Email Templates

Email templates use `templateType=email` and are subject to *very* different rules from web templates. Most HubL features work, but the rendering target (Gmail, Outlook, Apple Mail, Yahoo, mobile clients) constrains everything.

## Required tokens (HubSpot will refuse to send without these)

Every email template MUST include all of these somewhere in the rendered output:

```hubl
{# Unsubscribe — legally required #}
{{ unsubscribe_link }}                  {# rendered as a link in marketing emails #}
{# OR for transactional: #}
{{ unsubscribe_section }}              {# auto-generated section #}

{# Sender address — required by CAN-SPAM, GDPR equivalents #}
{{ company_name }}
{{ company_street_address_1 }}
{{ company_street_address_2 }}        {# optional second line #}
{{ company_city }}
{{ company_state }}
{{ company_postal_code }}
{{ company_country }}

{# View-in-browser fallback #}
{{ view_as_page_url }}
{# OR #}
{{ view_in_browser_link }}
```

`hs theme validate` checks for these. Missing → blocking.

## What's NOT allowed in email templates

- `{% form %}` — email clients don't render forms. Use a CTA link to a landing page.
- `<script>` — every major email client strips JS. Don't bother.
- `<iframe>` — same; stripped.
- External CSS via `<link rel="stylesheet">` — Gmail's mobile app doesn't load external CSS reliably. Inline styles or `<style>` in `<head>` only.
- `position: fixed` / `position: absolute` — broken in many clients.
- Complex CSS Grid / Flexbox — broken in Outlook 2007-2019 (Word rendering engine). Use `<table>`-based layouts for cross-client safety.

## What works (the canonical email shape)

```hubl
<!--
  templateType: email
  label: Promotional — single-CTA
-->
<!doctype html>
<html lang="{{ html_lang }}">
<head>
  <meta charset="utf-8">
  <meta http-equiv="X-UA-Compatible" content="IE=edge">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="format-detection" content="telephone=no, date=no, address=no, email=no">
  <title>{{ subject }}</title>
  <style type="text/css">
    /* Reset + base */
    body { margin: 0; padding: 0; -webkit-text-size-adjust: 100%; background: #F8FAFC; }
    table { border-collapse: collapse; }
    img { display: block; border: 0; outline: none; max-width: 100%; height: auto; }
    a { color: {{ module.link_color|default("#3B82F6") }}; text-decoration: underline; }

    /* Container */
    .email-container { max-width: 600px; margin: 0 auto; }

    /* Hero */
    .hero-h1 { font-family: Arial, sans-serif; font-size: 28px; line-height: 1.2; color: #0F172A; margin: 0 0 12px; }

    /* CTA button */
    .cta-button {
      display: inline-block; padding: 14px 28px; background: #0F172A; color: #FFFFFF !important;
      text-decoration: none; border-radius: 8px; font-family: Arial, sans-serif; font-weight: 600;
    }

    /* Mobile */
    @media (max-width: 600px) {
      .email-container { width: 100% !important; }
      .hero-h1 { font-size: 22px !important; }
      .stack-on-mobile { width: 100% !important; display: block !important; }
    }

    /* Dark mode (apple mail) */
    @media (prefers-color-scheme: dark) {
      body, .email-container { background: #0F172A !important; }
      .hero-h1 { color: #F8FAFC !important; }
    }
  </style>
</head>
<body>
  <table width="100%" cellpadding="0" cellspacing="0" border="0" role="presentation">
    <tr><td>
      <table class="email-container" cellpadding="0" cellspacing="0" border="0" role="presentation" width="600">

        <!-- Preheader (hidden but used by inbox preview) -->
        <tr><td style="display:none; max-height:0; overflow:hidden; mso-hide:all;">
          {{ module.preheader }}
        </td></tr>

        <!-- Header -->
        <tr><td style="padding: 24px 24px 16px;">
          <a href="{{ site_settings.companyDomain }}">
            <img src="{{ module.logo.src }}" alt="{{ module.logo.alt|default(company_name) }}" width="120">
          </a>
        </td></tr>

        <!-- Hero -->
        <tr><td style="padding: 24px;">
          <h1 class="hero-h1">{{ module.headline }}</h1>
          <p style="font-family: Arial, sans-serif; font-size: 16px; line-height: 1.5; color: #475569; margin: 0 0 24px;">
            {{ module.body }}
          </p>
          <a href="{{ module.cta_url|escape }}" class="cta-button">{{ module.cta_label }}</a>
        </td></tr>

        <!-- Footer (REQUIRED tokens) -->
        <tr><td style="padding: 24px; border-top: 1px solid #E2E8F0; font-family: Arial, sans-serif; font-size: 12px; color: #94A3B8;">
          <p style="margin: 0 0 8px;">
            {{ company_name }}<br>
            {{ company_street_address_1 }}{% if company_street_address_2 %}, {{ company_street_address_2 }}{% endif %}<br>
            {{ company_city }}, {{ company_state }} {{ company_postal_code }}
          </p>
          <p style="margin: 0;">
            <a href="{{ unsubscribe_link }}">Unsubscribe</a> ·
            <a href="{{ view_as_page_url }}">View in browser</a>
          </p>
        </td></tr>

      </table>
    </td></tr>
  </table>
</body>
</html>
```

Note the patterns:
- `<table>` layout (not flex/grid) — Outlook compatibility.
- Inline `style=""` AND a `<style>` block — different clients respect different sources.
- Arial / system fonts — most reliable across clients.
- `role="presentation"` on layout tables — accessibility (screen readers ignore them).
- Preheader as a hidden row.
- `mso-hide:all` for Outlook-specific hiding.

## Field-type picks for emails

| Job | Field type |
|---|---|
| Headline | `text` |
| Body copy | `richtext` (allows light formatting) |
| Image | `image` (with `responsive: false` — emails don't do srcset reliably) |
| CTA | `group` of `text` (label) + `url` (cta_url) |
| Preheader | `text` |
| Logo | `image` |

## Mobile responsiveness

`@media (max-width: 600px)` covers most mobile clients. Apple Mail / iOS Mail / Gmail mobile all support media queries; Outlook mobile has issues. Use the `stack-on-mobile` pattern for two-column layouts.

## Dark mode

Apple Mail / Outlook for Mac respect `prefers-color-scheme`. Gmail darkens light themes automatically (less control). Don't fight it; design for both.

## Accessibility for emails

- Every image needs `alt=""` (decorative) or descriptive `alt` text.
- Color contrast WCAG AA on body copy.
- Tap targets ≥ 44x44px.
- `lang="{{ html_lang }}"` on `<html>`.
- Use `role="presentation"` on layout tables.

## Cross-client testing

Out of scope for hsns v0.1 (no Litmus / Email-on-Acid integration). Manual checklist:

1. Send a test email to yourself in: Gmail web, Gmail mobile, Apple Mail (mac + iOS), Outlook desktop, Outlook web.
2. Check both light and dark mode.
3. Check forwarded copies (some clients re-render on forward).
4. Verify unsubscribe link works.

`/hsns:qa` runs `hs theme validate` and structural checks; it does not render across clients in v0.1.

## What `/hsns:nano` decides for emails

When `target: email`, the plan must specify:
- Email type: promotional, transactional, nurture, newsletter.
- `template_type: email`.
- A simpler `module_map` (often a single email-body module, no drag-drop).
- All required tokens included.
- Required `meta.json` `host_template_types: ["EMAIL"]` for any email modules.

## What `/hsns:review` and `/hsns:security` add for emails

- Required tokens present (unsubscribe, sender address, view-in-browser).
- No `<script>`, `{% form %}`, `<iframe>`.
- All `<a href>` use `|escape`.
- Dark-mode + mobile media queries present.
- Color contrast on body and CTA passes.
