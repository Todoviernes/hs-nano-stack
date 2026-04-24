# HubL cheatsheet

One-page quick reference. The full skill is `skills/hubl-syntax/SKILL.md`. Authoritative source: https://developers.hubspot.com/docs/cms/hubl

## Delimiters

| Use | Delimiter | Example |
|---|---|---|
| Output a value | `{{ }}` | `{{ module.headline }}` |
| Statement / control | `{% %}` | `{% if x %}…{% endif %}` |
| Comment | `{# #}` | `{# fix later #}` |

## Common variables

```hubl
{{ module.<name> }}              {# module field          #}
{{ theme.<group>.<name> }}       {# theme field           #}
{{ content.html_title }}         {# page title            #}
{{ content.absolute_url }}       {# canonical URL         #}
{{ content.publish_date }}       {# datetime              #}
{{ content.post_body }}          {# blog post HTML        #}
{{ request.query_dict.utm_source }}   {# query param      #}
{{ standard_header_includes }}   {# HubSpot head injection #}
{{ standard_footer_includes }}   {# HubSpot footer inject  #}
{{ company_name }}               {# email — sender info   #}
{{ unsubscribe_link }}           {# email — required      #}
{{ portal_id }}                  {# public                #}
{{ html_lang }}                  {# 'en-us', etc.         #}
{{ site_settings.companyDomain }}
```

## Control flow

```hubl
{% if x %}…{% elif y %}…{% else %}…{% endif %}
{% for item in module.items %}{{ loop.index }}: {{ item.x }}{% endfor %}
{% set count = 0 %}{% for x in xs %}{% set count = count + 1 %}{% endfor %}
{% block main %}default{% endblock %}
{% extends "../layouts/base.html" %}
{% include "../partials/header.html" %}
{% macro btn(label, url) %}<a href="{{ url|escape }}">{{ label }}</a>{% endmacro %}
```

## HubSpot tags

```hubl
{# drag-drop area (templateType=page or landing-page only) #}
{% dnd_area "main" %}{% dnd_section %}{% dnd_column %}
  {% dnd_module path="../modules/hero-split.module" %}
{% end_dnd_column %}{% end_dnd_section %}{% end_dnd_area %}

{# fixed module instance #}
{% module "hero" path="../modules/hero-split.module",
   headline="Welcome", image={ src: "/img/hero.jpg", alt: "Hero" } %}

{# HubSpot form embed #}
{% form
   form_to_use="<form-guid>"
   response_response_type="redirect"
   response_redirect_url="/thanks"
%}

{# Global partial #}
{% global_partial path="../partials/header.html" %}

{# Menu #}
{% menu name="primary_navigation" tree_type="static" %}

{# CTA #}
{% cta guid="<cta-guid>" %}

{# Require CSS / JS in module context #}
{% require_css %}<style>{% include "./module.css" %}</style>{% end_require_css %}
{% require_js position="footer" %}<script>{% include "./module.js" %}</script>{% end_require_js %}
```

## Filters (most used)

```hubl
{{ x | escape }}                  {# alias: e — HTML-escape #}
{{ x | safe }}                    {# DANGER: opt out of escape #}
{{ x | striptags }}               {# remove all HTML #}
{{ x | upper }} | lower | title | capitalize
{{ x | truncate(160) }}           {# cut at word boundary #}
{{ x | length }}                  {# string or list count #}
{{ x | default("fallback") }}
{{ x | replace('a', 'b') }}
{{ x | trim }}
{{ x | int }} | float | string
{{ x | urlencode }}
{{ x | datetimeformat('%B %e, %Y') }}
{{ x | round(2) }}
{{ x | pprint }}                  {# debug — pretty print #}
{{ list | join(', ') }}
{{ list | first }} | last | sort | unique | reverse
{{ url | startswith('https://') }}
```

## Field access shortcuts

```hubl
{{ module.image.src }}            {# image field           #}
{{ module.image.alt }}
{{ module.image.width }}
{{ module.image.height }}
{{ module.cta.url.href }}         {# url field             #}
{{ module.cta.url.type }}         {# EXTERNAL/CONTENT/...  #}
{{ module.color.color }}          {# color field           #}
{{ module.color.opacity }}
{{ module.font.font }}            {# font field            #}
{{ module.font.size }}
{{ module.font.size_unit }}
{{ module.choices_field }}        {# value of selected choice #}
{{ module.boolean_field }}        {# true/false (sometimes "true"/"false" string) #}
```

## Loop variables

```hubl
{% for x in xs %}
  {{ loop.index }}     {# 1-based         #}
  {{ loop.index0 }}    {# 0-based         #}
  {{ loop.first }}     {# bool            #}
  {{ loop.last }}      {# bool            #}
  {{ loop.length }}    {# total count     #}
  {{ loop.revindex }}  {# countdown       #}
{% endfor %}
```

## Comparison & logic

```hubl
{% if x == y %} == != < > <= >=
{% if x and y %}  and / or / not
{% if x in list %}  in / not in
{% if x is defined %} is defined / is none / is iterable / is divisibleby(N)
```

## Strings

```hubl
{{ "Hello " ~ module.name }}   {# concat with ~ (not +) #}
{{ "static text" }}
{{ '%s wins' | format(module.x) }}
```

## Dates

```hubl
{{ content.publish_date | datetimeformat('%B %e, %Y') }}    {# April 24, 2026 #}
{{ content.publish_date | datetimeformat('%Y-%m-%d') }}     {# 2026-04-24    #}
{{ unixtimestamp() }}                                        {# now           #}
```

## URL helpers

```hubl
{{ "/path" | absolute_url }}
{{ url | trim_path() }}
{{ url | urlencode }}
{{ url | escape }}            {# always before href= #}
```

## Common footguns

| Pattern | Why it bites | Fix |
|---|---|---|
| `{{ module.url }}` in `href` | not always escaped in attribute context | `\|escape` |
| `{{ module.x \| safe }}` on user input | XSS | only on system values; comment justification |
| `{% if module.bool == "true" %}` | string compare | `{% if module.bool %}` |
| `{% set x = 0 %}{% if y %}{% set x = 1 %}{% endif %}{{ x }}` works? | `set` scopes to the block | declare outside (already shown — works ONLY if outside set is preserved; safer: use namespace) |
| Multi-line `{{ ... \n ... }}` | parser bugs | one line |
| `<a href="">` from missing field | broken link | `{% if url %}<a>...</a>{% endif %}` |
| `{% for x in maybe_list %}` no items | silent zero loop | `{% if list \| length > 0 %}` |
| `{% include "./x.html" %}` wrong path | runtime error in portal | use portal-relative paths matching repo layout |

## Email-specific reminders

- No `<script>`, `{% form %}`, `<iframe>`.
- Required: `{{ unsubscribe_link }}`, `{{ company_name }}`, `{{ company_street_address_1 }}`, `{{ company_city }}`, `{{ view_as_page_url }}` (or `{{ view_in_browser_link }}`).
- `<table>` layouts, inline styles, web-safe fonts.
