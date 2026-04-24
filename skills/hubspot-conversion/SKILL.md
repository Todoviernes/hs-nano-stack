---
name: HubSpot Conversion Patterns
description: Use when designing or reviewing landing pages on HubSpot CMS Hub. Covers above-the-fold structure, CTA design, trust signals, form length, traffic-source-specific layouts, and the canonical landing-page recipes (lead capture, product launch, demo booking).
version: 1.0.0
---

# HubSpot Conversion Patterns

This skill encodes what works on HubSpot landing pages, distilled from hundreds of A/B tests and real-world deployments. The unit of work here is "the brief's KPI conversion goal converted through HubSpot's CMS primitives."

## The five-section canonical landing page

Most B2B landing pages should look like this. Add fewer sections (paid social), add more (organic search, intent-driven). Don't add for the sake of adding.

```
1. Hero (headline + subhead + primary CTA + trust signal)
2. Differentiators (3 features grid OR 3 stat tiles)
3. Proof (customer logos, testimonial, case-study link)
4. Risk-reversal (FAQ, demo-vs-trial choice, "no credit card")
5. CTA-form (lead capture)
```

Every section is a HubSpot module. The brief's `target: landing-page` typically maps to 3-5 modules from `reference/module-recipes/`.

## Above the fold (hero)

The hero is 80% of a landing page's job. Get it right.

### Headline rules

- **Names the outcome, not the feature.** "Send better email" is feature. "Reduce email-blast unsubscribe rate by 40%" is outcome.
- **Persona-specific.** "For ops managers running mid-market SaaS" beats "For everyone."
- **Concrete.** Numbers, time, scale. "Ship in 30 minutes" > "Ship fast."
- **5-12 words.** Longer headlines lose attention.

### Subhead rules

- **Says what the thing IS.** Headline is outcome; subhead is what you actually do.
- **Lists 1-3 capabilities.** Not 7.
- **Speaks the persona's language.** Technical persona → technical terms. Marketing persona → marketing terms. The brief's `brand_voice` is your guide.

### Primary CTA rules

- **One CTA, not three.** A second CTA splits intent.
- **Action verb + outcome.** "Get my demo" beats "Submit." "See the dashboard" beats "Learn more."
- **Visible on mobile (375x812) without scrolling.** This is non-negotiable for paid-social traffic.
- **High contrast against the hero background.** WCAG AA at minimum.

### Trust signals near the hero

- 3-6 customer logos (recognizable).
- Or: a single one-line quote from a named customer.
- Or: a single "trusted by X teams" stat.

If you have NONE of these, skip — fake trust signals destroy trust faster than no trust signals.

## Differentiators (section 2)

Three's the magic number. More than three dilutes; fewer than three feels thin.

```hubl
<section class="features">
  <h2>{{ module.section_headline }}</h2>
  <div class="features__grid">
    {% for feature in module.features %}
      <article class="feature">
        {% if feature.icon.name %}<i class="fas fa-{{ feature.icon.name }}"></i>{% endif %}
        <h3>{{ feature.headline }}</h3>
        <div class="feature__body">{{ feature.body }}</div>
      </article>
    {% endfor %}
  </div>
</section>
```

For each feature:
- **Headline is the differentiator name.** "Phase gates" not "Quality assurance system."
- **Body is concrete benefit.** "Review, security, QA before any portal touches" > "Comprehensive quality controls."
- **Icon is optional.** If used, consistent style (all line-icons or all solid; not mixed).

Use `fields.json` `group` with `occurrence` for the repeater so editors can add/remove features.

## Proof (section 3)

Three formats, in order of preference:

1. **Named-customer quote with photo.** "Sarah Chen, VP Ops at Linear: '... we shipped in 3 days.'"
2. **Case study link with metric.** "Linear cut their landing-page deploy time by 90% with hsns. Read the case study."
3. **Customer logo grid.** Lower trust per logo than a quote, but easy to scale.

Avoid: anonymous quotes, generic "trusted by 1000+ teams" without specifics.

## Risk reversal (section 4) — optional

Only when you've identified a specific objection. Common patterns:

- **FAQ accordion** — preempts objections. Use when traffic is research-mode (organic search).
- **"No credit card required" / "Free for X" / "Setup in 5 minutes"** — reduces commitment friction.
- **Demo vs. trial choice** — "Want to see it? Book a demo. Want to try it? Start free." Two paths from one section.

For paid-social traffic, often the right call is to skip this section — the persona is decision-mode, not research-mode.

## CTA-form (section 5)

The form is where conversion either happens or doesn't. Three rules:

### Field count matches value exchange

| Value exchange | Field count |
|---|---|
| Email-only newsletter | 1 (email) |
| Whitepaper / report download | 2-3 (email, name, optionally company) |
| Webinar registration | 3-4 |
| Demo booking | 4-6 (email, name, company, role, optionally team size) |
| Free trial / signup | 5-7 |

Each extra field cuts conversion by ~7-15%. Cut unless it's used for sales qualification.

### Submit button copy

- **The action.** "Get my demo" / "Send the report" / "Save my spot" / "Start my trial."
- **Not generic.** Never "Submit." Almost never "Sign up."
- **First-person possessive.** "my" / "our" / "I" — increases conversion 5-10% in tests.

### Form placement

- **Paid social** → form near top. Persona is impatient, intent is high.
- **Warm email** → form after pitch. Already-convinced persona reads the pitch they want to share.
- **Organic search** → form at end, after proof and FAQ. Research-mode persona.

In HubSpot, drop the form via the `form` field type and `{% form %}` tag (HubSpot's embed). Don't roll a custom form unless you have a specific reason — HubSpot's form has CRM integration, spam filtering, GDPR consent, conditional fields, and reCAPTCHA built in.

## Mobile defaults (paid-social-aware)

>50% of paid-social traffic is mobile. Build mobile-first.

- Hero: single-column. Image stacks below copy.
- Tap targets ≥ 44x44px (iOS HIG / Material Design).
- CTA fills width on mobile.
- Form fields full-width.
- No hover-only interactions.

## What `/hsns:nano` decides for landing pages

When `target: landing-page`, the architect agent (`hs-architect`) plans:

- `module_map` — typically: `hero-split` + `feature-grid` + `cta-form`. Add `proof-logos` or `testimonial-card` if the brief mentions trust signals.
- `dnd_strategy: single-area` — one editable canvas. Editor can rearrange or add sections.
- `content_schema` — realistic copy in the brief's voice. Not Lorem ipsum.
- `success_signals` — Lighthouse mobile ≥ 85, form submits on sandbox, all `fields.json` keys referenced.

## Measurement (post-launch)

After `/hsns:ship`, track:

- **Form submission rate** = submissions / unique visitors.
- **Bounce rate** by traffic source.
- **Time on page** — short for paid social (good), long for organic (good).
- **Scroll depth** to the CTA-form section.

HubSpot's analytics expose all of this per landing-page automatically. Consumer repos can add a `success_signals` carry-over to future `/hsns:think` briefs to set baselines.
