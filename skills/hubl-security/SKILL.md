---
name: HubL Security
description: Use when reviewing HubSpot CMS code for HubL XSS via `|safe`, secrets in shipped JS, unsafe form actions, CSP-incompatible patterns, and OWASP issues specific to HubSpot-hosted forms. Companion to /hsns:security.
version: 1.0.0
---

# HubL Security

HubL renders server-side; it auto-escapes most output. The vulnerabilities specific to HubSpot are: (1) `|safe` filter mis-use, (2) secrets in client-shipped code, (3) unsafe form/redirect handling, (4) CSP-incompatible inline JS/handlers, (5) data-handling issues that compound at HubSpot scale.

## 1. The `|safe` filter — primary XSS vector

HubL escapes by default. `|safe` opts out, rendering the value as raw HTML. This is the #1 source of HubSpot XSS.

**When `|safe` is dangerous:**
- On a `text` field — the editor can paste a script tag and HubL will render it as runnable HTML.
- On a `richtext` field WITHOUT trusting HubSpot's editor sanitization — though in practice the editor does sanitize on save.
- On a `url` field — pasting a `javascript:` scheme value gets rendered into `<a href="">` and clicked = code execution.

**When `|safe` is justified:**
- HubSpot system values: `{{ content.absolute_url|safe }}` — these are URLs HubSpot constructed, safe by trust.
- After explicit sanitization: `{{ value|striptags|safe }}` — `striptags` removes all HTML, `safe` ensures it isn't double-escaped.
- Raw HTML literals embedded into HubL: `{{ "<svg>...</svg>"|safe }}` — author-controlled, not editor-controlled.

**Discipline:** every `|safe` use should have a comment explaining why:
```hubl
{# safe-after-striptags #}
{{ module.user_supplied_html | striptags | safe }}

{# safe-system-value #}
{{ content.absolute_url|safe }}

{# safe-after-editor-sanitization #}
{# HubSpot's richtext editor sanitizes on save; |safe avoids double-escaping the stored HTML. #}
{{ module.subhead | safe }}
```

`/hsns:security` triages every `|safe` and demands a justification comment for each.

## 2. Attribute-context escaping

HubL's auto-escape covers HTML body context but is less aggressive in attribute contexts. Always be explicit:

```hubl
{# WEAK — relies on auto-escape #}
<a href="{{ module.cta_url }}">

{# STRONG — explicit #}
<a href="{{ module.cta_url|escape }}">

{# WEAK — javascript: scheme not blocked #}
<a href="{{ module.cta_url }}">

{# STRONG — validate the scheme too #}
{% if module.cta_url|lower|startswith("https://") or module.cta_url|startswith("/") %}
  <a href="{{ module.cta_url|escape }}">…</a>
{% endif %}
```

**JSON-in-HTML:** use `|escape` (or build it server-side and stick the JSON in a data attribute):
```hubl
{# WEAK — XSS in JSON via " injection #}
<script>const data = {{ module.json|safe }};</script>

{# STRONG #}
<script id="data" type="application/json">{{ module.json|escape }}</script>
<script>const data = JSON.parse(document.getElementById('data').textContent);</script>
```

## 3. Secrets in shipped code

`module.js`, inline `<script>`, `module.css`, and any HubL template **all ship to the browser**. Anything an end user can read.

**Never put in shipped code:**
- API keys, secrets, tokens, bearer tokens, basic-auth headers.
- HubSpot Personal Access Keys (and they should never be in repo, gitignored).
- Internal admin URLs / staging hosts.
- Customer PII or business-confidential data.

**OK in shipped code:**
- Tracking IDs (GA4 `G-XXXX`, Meta Pixel ID, GTM container ID, HubSpot tracking ID).
- HubSpot portal IDs (`{{ portal_id }}` is public).
- Public CDN URLs.

**Where `/hsns:security` looks:** every `*.js`, `*.html`, `*.css` in the repo. Heuristic:
```bash
grep -rEn '(api[_-]?key|secret|token|password|bearer)\s*[:=]\s*["'\''][^"'\''\s]{16,}'
```

## 4. Form actions and redirects

HubSpot forms via `{% form %}` are safe by default — HubSpot handles submission, spam filtering, validation, and CSRF.

**Custom `<form action="...">`:**
- Action URL must be HTTPS.
- The receiving endpoint must verify origin or use a CSRF token. Without that → `blocking`.

**`response_redirect_url`:**
- Must be same-origin (`/thanks`) or an explicit allowlisted external domain.
- An open redirect (`response_redirect_url={{ request.query_dict.next }}`) is a phishing vector — `blocking`.

**Form method:**
- POST for any form with PII or business-meaningful data.
- GET for search forms only (and explicitly never with sensitive fields — they leak via referrers).

## 5. CSP compatibility

HubSpot doesn't enforce CSP by default. But customer portals often do (regulated industries, compliance teams). Build CSP-friendly by default:

**Avoid:**
- Inline event handlers like `<button onclick="...">` → `blocking` (also XSS-prone).
- Inline `<script>` without a nonce — `should_fix`. Move JS to `module.js`.
- `<script src="https://...">` from non-HubSpot CDNs without SRI hashes → `should_fix`.
- Dynamic code execution primitives — any path that turns a string into runnable code at runtime → `blocking`.

**Prefer:**
- All JS in `module.js` (or a theme-level `js/main.js`).
- Event delegation in JS, not inline handlers.
- HubSpot-CDN-hosted assets (auto-trusted).

## 6. PII handling

For lead-capture forms:
- Never put PII in URL query parameters (referer leaks).
- `autocomplete="off"` on fields where stored auto-fill is harmful (security questions, payment); allow on standard fields (`new-password`, `current-password`).
- Server-side rate limiting on form endpoints (HubSpot does this for `{% form %}`; custom endpoints must implement).
- Honeypot fields on HubSpot forms (recommended; `/hsns:security` flags missing as `nitpick`).

## 7. Compliance basics (EU/UK/CA traffic)

For pages serving EU/UK/CA visitors:
- Tracking pixels should fire AFTER cookie consent.
- HubSpot's `standard_header_includes` injects tracking; consent integration is a portal-level setting.
- Privacy/terms links visible in footer.
- Form must show "we'll email you" or similar consent copy.

## Common patterns and verdicts

| Pattern | Verdict |
|---|---|
| `{{ module.text }}` | safe (auto-escaped) |
| `{{ module.richtext }}` | safe (richtext is HTML; HubSpot sanitizes on save) |
| `{{ module.text \| safe }}` | **blocking** unless justified |
| `{{ module.url \| escape }}` in `href=""` | safe |
| `<a href="{{ module.url }}">` | should_fix → add `\|escape` |
| `<button onclick="...">` | **blocking** (CSP + XSS) |
| `<script>const x = {{ module.json }};</script>` | **blocking** — use data-attribute |
| `<script>const x = "{{ module.text }}";</script>` | should_fix — quote injection |
| `<form action="https://api.example.com/lead" method="post">` (3rd-party) | needs origin/CSRF on receiving end |
| `response_redirect_url="{{ request.query_dict.next }}"` | **blocking** — open redirect |
| API key in `module.js` | **blocking** |
| GA4 ID in `module.js` | safe |
| `eyJ...` JWT in shipped code | **blocking** (likely a leaked credential) |

## What `/hsns:security` runs

1. `scripts/hubl-lint.sh` for the `|safe`-on-module-var heuristic.
2. The grep heuristics above for secrets.
3. A walk over every `<form>`, `<a>`, `<script>` tag for context-specific checks.
4. Aggregates findings into `.hs-nano/security/<TS>.json` with category + OWASP ref + suggestion.
