---
name: HubSpot Performance
description: Use when optimizing or reviewing Core Web Vitals on HubSpot CMS pages. Covers image optimization (URL params, fetchpriority, lazy loading), font-loading strategies, render-blocking JS, the HubSpot tracking script, and the Lighthouse-to-fix mapping.
version: 1.0.0
---

# HubSpot Performance

HubSpot pages on `*.hubspotpreview-<region>.com` and live customer domains are served from HubSpot's CDN. Performance is mostly about what your HubL/CSS/JS contains, not how HubSpot serves it.

## The four things that matter

1. **LCP (Largest Contentful Paint)** — usually the hero image or hero headline.
2. **CLS (Cumulative Layout Shift)** — image dimensions and font swap.
3. **INP (Interaction to Next Paint)** — JS payload and main-thread blocking.
4. **TTFB / FCP** — HubSpot's CDN handles this; you have limited control.

Target on mobile (the hard target):
- Performance score ≥ 85
- LCP ≤ 2.5s
- CLS ≤ 0.1
- INP ≤ 200ms

## Image optimization (LCP)

The hero image is almost always the LCP element. Three wins:

### Use HubSpot's URL transform params

```hubl
{# Resize to 1600px max width, output webp #}
<img src="{{ module.image.src|replace('?', '?width=1600&format=webp&')|escape }}"
     alt="{{ module.image.alt }}">
```

Or in the source URL itself (HubSpot's File Manager appends params via URL):
```
https://your-portal.hubspotusercontent.com/hubfs/hero.jpg?width=1600&format=webp
```

Conversion is automatic on serve. WebP is ~30% smaller than JPG at equivalent quality.

### Mark the hero with `fetchpriority` and skip lazy

```hubl
<img src="{{ module.hero_image.src }}"
     alt="{{ module.hero_image.alt }}"
     width="1600" height="900"
     fetchpriority="high"
     loading="eager"
     decoding="async">
```

Below the fold, do the opposite:
```hubl
<img src="{{ feature.image.src }}"
     alt="{{ feature.image.alt }}"
     width="800" height="600"
     loading="lazy"
     decoding="async">
```

### Always include `width` and `height`

Prevents CLS as the image loads. HubSpot's `image` field returns these:
```hubl
<img src="{{ module.image.src }}"
     alt="{{ module.image.alt }}"
     width="{{ module.image.width|default(1600) }}"
     height="{{ module.image.height|default(900) }}">
```

### Preload the hero

```hubl
{% block head %}
  <link rel="preload" as="image" href="{{ module.hero_image.src }}" fetchpriority="high">
{% endblock %}
```

## Font loading (CLS + LCP)

Web fonts can be the slowest asset on a page.

### Use `font-display: swap`

If using `@font-face`:
```css
@font-face {
  font-family: 'Inter';
  src: url('/path/to/inter.woff2') format('woff2');
  font-display: swap;
  font-weight: 400 700;
}
```

Without `swap`, text is invisible until the font loads (FOIT). With `swap`, fallback renders immediately and swaps when the font is ready (FOUT) — better LCP, worse CLS unless you size-match.

### Preconnect to font CDNs

```html
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter:wght@400;700&display=swap">
```

### Limit weight count

3 web font weights max (e.g., 400, 500, 700). Each weight is a separate file fetch.

### Match font metrics to reduce CLS

Chrome supports `size-adjust`, `ascent-override`, `descent-override` for fallback fonts. Use [fontaine](https://github.com/unjs/fontaine) or generate manually:

```css
@font-face {
  font-family: 'Inter Fallback';
  src: local('Arial');
  size-adjust: 107%;
  ascent-override: 90%;
  descent-override: 22%;
  line-gap-override: 0%;
}

body { font-family: 'Inter', 'Inter Fallback', sans-serif; }
```

Now the fallback `Inter Fallback` (mapped to Arial with adjusted metrics) reserves the same space as Inter — when Inter loads, no shift.

## JavaScript (INP + Performance)

### Order of operations

```
HEAD:
- preconnect
- preload critical fonts/images
- inline critical CSS (optional)
- (NO render-blocking JS here)

BODY:
- HubSpot standard_header_includes (this is required)
- (NOT here — moved scripts to before </body>)

BEFORE </body>:
- module.js files (deferred)
- third-party JS (analytics, chat) async
- HubSpot standard_footer_includes
```

### Defer non-essential

```html
<script src="/js/main.js" defer></script>
<script src="https://chat.example.com/widget.js" async></script>
```

`defer` runs after parsing but in document order. `async` runs whenever, no order. Use `async` for analytics, `defer` for module init.

### Avoid heavy `module.js`

Most modules don't need JS. CSS handles 90% of interactivity (hover, focus, click via `:has()`, animation). Reach for JS only for:
- State that persists (a tab UI that remembers selection).
- Network calls (search-as-you-type).
- Animations beyond CSS capability.

### HubSpot's tracking script

`{{ standard_header_includes }}` injects HubSpot's analytics. It's necessary for the customer's CRM. Don't try to remove it. Its impact on Lighthouse is bounded; accept it.

## Render-blocking CSS

HubSpot bundles theme CSS automatically. Optimize by:

- Keep `css/main.css` lean. Avoid CSS frameworks if you only use 5%.
- Use CSS variables for theming (one `:root { ... }` block) instead of multiple `body.theme-dark { ... }` overrides.
- Module CSS via `{% require_css %}{% include "./module.css" %}{% end_require_css %}` — HubSpot deduplicates and concatenates.

## Third-party tags

Common offenders:
- Chat widgets (Intercom, Drift) — heavy. `async`.
- Analytics (GA4, Meta Pixel) — light. `async`.
- A/B testing (Optimizely) — render-blocking by design. Audit if needed.
- Customer data platforms (Segment) — heavy if loaded synchronously. `async`.

Each third-party tag costs Lighthouse points. Justify each.

## Lighthouse audit-to-fix lookup

| Lighthouse audit ID | Likely fix |
|---|---|
| `largest-contentful-paint-element` | Hero image: add fetchpriority, compress, preload |
| `cumulative-layout-shift` | Add width/height to all images; font-display: swap; size-adjust fallback |
| `total-blocking-time` | Defer non-critical JS; remove unused JS |
| `unused-css-rules` | Trim module.css; remove unused framework CSS |
| `unused-javascript` | Remove unused libraries; tree-shake |
| `render-blocking-resources` | Move scripts to before </body>; defer/async |
| `efficient-animated-content` | Replace GIFs with `<video>` or static images |
| `properly-sized-images` | Use HubSpot URL params to resize |
| `modern-image-formats` | Use `format=webp` URL param |
| `legacy-javascript` | Don't ship polyfills; modern browsers only |
| `uses-text-compression` | HubSpot enables gzip/brotli; if flagged, check custom assets |

## Quick wins (mobile performance ≥ 85 with no extra effort)

These five fixes alone usually push a HubSpot landing page from ~70 to ~85+:

1. Hero image: fetchpriority="high" + width/height + format=webp.
2. Below-fold images: loading="lazy".
3. Font: `font-display: swap`.
4. Move all `<script>` to before `</body>` with `defer`.
5. Remove unused CSS framework imports.

## What `/hsns:qa` measures

- Lighthouse mobile audit on the sandbox preview URL.
- Aggregates scores into `qa.lighthouse_scores`.
- Pulls Core Web Vitals into `qa.core_web_vitals`.
- Failed audits go to `hs-perf-reviewer` for diagnosis and fix recommendations.
