---
name: HubSpot Accessibility
description: Use when reviewing HubSpot CMS modules, templates, and emails for WCAG 2.1 AA compliance. Covers semantic HTML, focus management, color contrast, ARIA on HubSpot forms, image alt text, keyboard navigation, and the Lighthouse a11y audit mapping.
version: 1.0.0
---

# HubSpot Accessibility

Accessibility on HubSpot is mostly about the HTML you write — HubSpot doesn't auto-fix bad markup. The two big sources of issues are: (1) HubL templates that wrap content in non-semantic divs, (2) HubSpot's form embed (`{% form %}`) inheriting from the surrounding theme.

## WCAG 2.1 AA targets

- **Color contrast.** Body text 4.5:1; large text (>18pt or >14pt bold) 3:1; UI components and graphics 3:1.
- **Keyboard navigation.** Every interactive element reachable + activatable with keyboard.
- **Focus indicators.** Visible on all focusable elements.
- **Semantic markup.** Headings in order; landmarks (header, main, footer); buttons are `<button>`, links are `<a>`.
- **Alt text.** Every content image; empty `alt=""` for decorative.
- **Form labels.** Every input has an associated `<label>`.

## Semantic HTML in HubL

Modules render as fragments inside a page. Build with semantic elements, not divs.

```hubl
{# WEAK #}
<div class="hero">
  <div class="hero__title">{{ module.headline }}</div>
  <div class="hero__cta" onclick="...">{{ module.cta_label }}</div>
</div>

{# STRONG #}
<section class="hero" aria-labelledby="hero-headline">
  <h1 id="hero-headline" class="hero__title">{{ module.headline }}</h1>
  <a class="hero__cta btn btn--primary" href="{{ module.cta_url|escape }}">{{ module.cta_label }}</a>
</section>
```

### Heading order

The page's heading order should be linear: `<h1>` → `<h2>` → `<h3>`. No skipping `<h2>` to `<h4>`.

In modules: typically the hero module owns `<h1>`, feature modules use `<h2>`. Modules like a "stat tile" might use `<h3>`. Don't put `<h1>` in a module that could appear multiple times on a page.

### Landmarks

```hubl
<body>
  {% global_partial path="../partials/header.html" %}
  {# header.html should wrap nav in <header><nav>...</nav></header> #}

  <main id="main-content">
    {% dnd_area "main_content" %}{% end_dnd_area %}
  </main>

  {% global_partial path="../partials/footer.html" %}
  {# footer.html should wrap in <footer> #}
</body>
```

A "Skip to main content" link is good practice:
```hubl
<a class="skip-link" href="#main-content">Skip to main content</a>
```
With CSS to make it visible only on focus:
```css
.skip-link {
  position: absolute; left: -10000px; top: 0;
}
.skip-link:focus { left: 16px; top: 16px; background: #fff; padding: 8px 16px; z-index: 9999; }
```

## Buttons vs links

- `<a href>` — navigates somewhere. Has a destination.
- `<button>` — triggers an action. No destination.

Don't use `<a onclick="...">` (no href). Don't use `<button onclick="window.location='...'">` (no destination).

## Images

```hubl
{# Content image — needs descriptive alt #}
<img src="{{ module.image.src }}"
     alt="{{ module.image.alt }}"
     width="{{ module.image.width }}" height="{{ module.image.height }}">

{# Decorative image — empty alt, role=presentation #}
<img src="{{ module.bg.src }}" alt="" role="presentation"
     width="{{ module.bg.width }}" height="{{ module.bg.height }}">
```

Discipline:
- Every `image` field in `fields.json` includes an `alt` default. Don't ship empty alt unless decorative.
- For SVG icons inline, add `aria-hidden="true"` if decorative, `<title>` if conveying meaning.

## Color contrast

CSS variables make this manageable. The theme picker should enforce contrast:
- `--color-text` against `--color-bg` ≥ 4.5:1.
- `--color-primary` (CTA bg) against `#FFFFFF` (CTA text) ≥ 4.5:1.

Test with browser dev tools or Lighthouse. If the theme allows the editor to break contrast (custom color picker), document the constraint in the field's `help_text`:
```json
{
  "name": "primary",
  "type": "color",
  "default": { "color": "#0F172A", "opacity": 100 },
  "help_text": "Used for CTA buttons. Pick a color with at least 4.5:1 contrast against white."
}
```

## Forms

HubSpot's `{% form %}` embed renders its own labels and structure. Two checks:

### Don't break the embed's a11y by overriding too aggressively

```css
/* WEAK — strips structure HubSpot relies on */
.hs-form input { all: unset; ... }

/* STRONG — restyles while preserving labels and focus */
.hs-form-field label { font-weight: 500; }
.hs-form input,
.hs-form textarea,
.hs-form select {
  width: 100%; padding: 12px; font-size: 16px;
  border: 1px solid #CBD5E1; border-radius: 6px;
}
.hs-form input:focus,
.hs-form textarea:focus,
.hs-form select:focus {
  outline: 2px solid var(--color-primary); outline-offset: 2px;
}
```

Keep visible focus indicators. Don't `outline: none;` without replacing.

### Custom forms (rare)

If rolling a custom `<form>`:
- Every input needs `<label for="...">` or `<label>` wrapping the input.
- Required fields: `required` attribute AND visible asterisk + `aria-required="true"`.
- Errors: `aria-invalid="true"` on the input + `<span id="x-err" role="alert">` linked via `aria-describedby="x-err"`.

## Keyboard navigation

Walk the page with Tab. Every interactive element should be reachable in a sane order.

- `<button>` and `<a href>` are tabbable by default.
- `<div onclick>` is NOT tabbable. Don't do this.
- `tabindex="-1"` removes from tab order; only for elements you focus programmatically.
- `tabindex="0"` adds to tab order; rare.
- `tabindex` > 0 is almost always wrong.

Verify focus indicators are visible (not `outline: none` without replacement).

## ARIA — only when semantic HTML doesn't cut it

Five rules:
1. Use the right HTML element first (`<button>` not `<div role="button">`).
2. Don't add `aria-*` if the underlying element already provides it (`<input type="checkbox">` doesn't need `aria-checked`).
3. `aria-label` is an override; use sparingly.
4. `role="presentation"` on layout `<table>` (used in emails) is correct.
5. `aria-hidden="true"` removes from accessibility tree; use only on decorative duplicate content.

## Module patterns

### Toggle / disclosure

```hubl
<button type="button"
        class="disclosure"
        aria-expanded="false"
        aria-controls="faq-{{ loop.index }}-body">
  {{ faq.question }}
</button>
<div id="faq-{{ loop.index }}-body" class="disclosure__body" hidden>
  {{ faq.answer }}
</div>
```
JS toggles `aria-expanded` and `hidden`. Keyboard-accessible by default.

### Modal / dialog

Out of scope for v0.1 — modals on landing pages are a known conversion killer. If absolutely needed, use `<dialog>` element (modern browsers) with focus management on open/close.

### Carousel

Avoid on landings. If unavoidable, follow the [APG carousel pattern](https://www.w3.org/WAI/ARIA/apg/patterns/carousel/) — `aria-roledescription="carousel"`, focus management on slide change, pause-on-hover, etc.

## Lighthouse a11y audit mapping

| Audit | Cause | Fix |
|---|---|---|
| `image-alt` | `<img>` without `alt` | Add `alt`; empty for decorative |
| `link-name` | `<a>` without text or aria-label | Add visible text or aria-label |
| `button-name` | `<button>` without text | Add text content |
| `color-contrast` | text/background contrast < 4.5:1 | Adjust theme colors |
| `form-field-multiple-labels` | input has 2+ labels | Use one `<label>` |
| `heading-order` | h1 → h3 (skipped h2) | Linearize heading hierarchy |
| `meta-viewport` | missing viewport meta | Add `<meta name="viewport" ...>` |
| `aria-allowed-attr` | invalid aria-* on element | Remove invalid attrs |
| `tabindex` | tabindex > 0 | Set to 0 or remove |

## What `/hsns:qa` runs

1. Lighthouse mobile audit (`accessibility` category).
2. Multi-breakpoint screenshots for visual a11y review (focus indicators visible? text readable?).
3. Manual checks: tab order, alt-text completeness, contrast on hero CTA.

Aggregates findings into `qa.a11y_violations[]`.
