#!/usr/bin/env bash
# fields-schema-check.sh — validate that a module's fields.json keys match the
# {{ module.<key> }} references in module.html.
#
# Usage:
#   scripts/fields-schema-check.sh path/to/some.module/
#
# Exits 0 if clean, 1 if mismatch (still prints a JSON report on stdout).

set -euo pipefail

DIR="${1:-}"

if [ -z "$DIR" ] || [ ! -d "$DIR" ]; then
  echo '{"error":"directory missing"}' >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo '{"error":"jq required"}' >&2
  exit 2
fi

fields_file="$DIR/fields.json"
html_file="$DIR/module.html"

if [ ! -f "$fields_file" ]; then
  jq -n --arg dir "$DIR" '{error:"fields.json missing", dir:$dir}'
  exit 1
fi
if [ ! -f "$html_file" ]; then
  jq -n --arg dir "$DIR" '{error:"module.html missing", dir:$dir}'
  exit 1
fi

# Extract field names from fields.json. HubSpot fields are array-of-objects,
# possibly nested under group children. We walk recursively.
field_keys="$(jq -r '
  def walk_fields:
    if type == "array" then
      .[] | walk_fields
    elif type == "object" then
      ( select(.name) | .name ),
      ( .children // empty | walk_fields )
    else empty end;
  . | walk_fields
' "$fields_file" | sort -u)"

# Extract referenced keys from module.html. Pattern: {{ module.<key> ... }} or
# {{ module.<key>.something ... }}.
# Note: BSD/macOS sed lacks `\b`, so we anchor by literal "module.".
ref_keys="$(grep -oE 'module\.[a-zA-Z0-9_]+' "$html_file" 2>/dev/null \
            | sed -E 's/^module\.([a-zA-Z0-9_]+)$/\1/' \
            | sort -u || true)"

# Compute differences using comm.
defined_only="$(comm -23 <(printf '%s\n' "$field_keys") <(printf '%s\n' "$ref_keys") | grep -v '^$' || true)"
referenced_only="$(comm -13 <(printf '%s\n' "$field_keys") <(printf '%s\n' "$ref_keys") | grep -v '^$' || true)"

mismatch=0
[ -n "$defined_only" ] && mismatch=1
[ -n "$referenced_only" ] && mismatch=1

jq -n \
  --arg dir "$DIR" \
  --arg defined_only "$defined_only" \
  --arg referenced_only "$referenced_only" \
  '{
    dir: $dir,
    defined_in_fields_json_but_unused_in_html: ($defined_only | split("\n") | map(select(length>0))),
    referenced_in_html_but_missing_from_fields_json: ($referenced_only | split("\n") | map(select(length>0))),
    clean: (($defined_only | length) == 0 and ($referenced_only | length) == 0)
  }'

exit $mismatch
