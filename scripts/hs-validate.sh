#!/usr/bin/env bash
# hs-validate.sh — two-layer theme validator.
#
# Layer 1 (always runs, no portal needed): local schema check — parses theme.json,
# fields.json, every module's meta.json/fields.json/module.html for shape, and
# every page/landing template for required HubL globals.
#
# Layer 2 (opt-in, requires portal): if --account=<name> AND --remote=<path>
# are both passed, runs `hs cms theme marketplace-validate <remote> --account=<name>`
# against the already-uploaded theme.
#
# Output: a JSON object usable as qa.hs_validate_output.
# Exit codes:
#   0 — all green
#   1 — at least one layer reported errors (still emits JSON)
#   2 — bad input (theme dir missing, jq missing, etc.)
#
# Usage:
#   scripts/hs-validate.sh ./my-theme                              # layer 1 only
#   scripts/hs-validate.sh ./my-theme --account=sandbox --remote=my-theme   # both layers

set -uo pipefail

THEME=""
ACCOUNT=""
REMOTE=""

for arg in "$@"; do
  case "$arg" in
    --account=*) ACCOUNT="${arg#--account=}" ;;
    --remote=*)  REMOTE="${arg#--remote=}" ;;
    --*)         ;;
    *)           [ -z "$THEME" ] && THEME="$arg" ;;
  esac
done

if [ -z "$THEME" ] || [ ! -d "$THEME" ]; then
  echo '{"error":"theme dir missing or not provided"}' >&2
  exit 2
fi

if ! command -v jq > /dev/null 2>&1; then
  echo '{"error":"jq required (brew install jq)"}' >&2
  exit 2
fi

# ──────────────────────────────────────────────────────────────────────
# Layer 1 — local schema check
# ──────────────────────────────────────────────────────────────────────
findings='[]'
add() {
  findings="$(jq --arg level "$1" --arg file "$2" --arg rule "$3" --arg msg "$4" \
    '. + [{level:$level, rule:$rule, file:$file, message:$msg}]' <<<"$findings")"
}

# theme.json shape
tj="$THEME/theme.json"
if [ ! -f "$tj" ]; then
  add "error" "theme.json" "missing-required-file" "theme.json missing at theme root"
elif ! jq -e . "$tj" >/dev/null 2>&1; then
  add "error" "theme.json" "invalid-json" "theme.json is not valid JSON"
else
  for k in label version preview_path; do
    v="$(jq -r ".${k} // empty" "$tj")"
    [ -z "$v" ] && add "warn" "theme.json" "missing-field" "missing recommended field: $k"
  done
  ver="$(jq -r '.version // empty' "$tj")"
  if [ -n "$ver" ] && ! [[ "$ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
    add "warn" "theme.json" "non-semver" "version is not SemVer: $ver"
  fi
fi

# theme-level fields.json shape
fj="$THEME/fields.json"
if [ -f "$fj" ]; then
  if ! jq -e 'type == "array"' "$fj" >/dev/null 2>&1; then
    add "error" "fields.json" "wrong-shape" "theme-level fields.json must be a top-level JSON array"
  fi
fi

# Every module
while IFS= read -r mod; do
  rel="${mod#$THEME/}"
  for required in module.html fields.json meta.json; do
    [ -f "$mod/$required" ] || add "error" "$rel" "missing-module-file" "module is missing $required"
  done

  if [ -f "$mod/meta.json" ]; then
    if ! jq -e . "$mod/meta.json" >/dev/null 2>&1; then
      add "error" "$rel/meta.json" "invalid-json" "meta.json is not valid JSON"
    else
      for k in label version host_template_types is_available_for_new_content; do
        v="$(jq -r ".${k} // empty" "$mod/meta.json")"
        [ -z "$v" ] && add "warn" "$rel/meta.json" "missing-field" "missing field: $k"
      done
      vt="$(jq -r '.version | type' "$mod/meta.json")"
      [ "$vt" = "number" ] || add "error" "$rel/meta.json" "version-not-integer" "module version must be an integer; got type=$vt"
      ht="$(jq -r '.host_template_types | type' "$mod/meta.json")"
      [ "$ht" = "array" ] || add "error" "$rel/meta.json" "host-not-array" "host_template_types must be an array"
    fi
  fi

  if [ -f "$mod/fields.json" ]; then
    if ! jq -e 'type == "array"' "$mod/fields.json" >/dev/null 2>&1; then
      add "error" "$rel/fields.json" "wrong-shape" "module fields.json must be a top-level array"
    fi
  fi
done < <(find "$THEME/modules" -type d -name '*.module' 2>/dev/null || true)

# Every page/landing-page template needs standard_*_includes
while IFS= read -r tmpl; do
  if head -n 10 "$tmpl" | grep -qE 'templateType:[[:space:]]*(page|landing-page)'; then
    rel="${tmpl#$THEME/}"
    grep -q 'standard_header_includes' "$tmpl" \
      || add "error" "$rel" "missing-header-includes" "page/landing-page template missing {{ standard_header_includes }}"
    grep -q 'standard_footer_includes' "$tmpl" \
      || add "error" "$rel" "missing-footer-includes" "page/landing-page template missing {{ standard_footer_includes }}"
  fi
done < <(find "$THEME/templates" -name '*.html' 2>/dev/null || true)

l1_errors="$(jq '[.[] | select(.level=="error")] | length' <<<"$findings")"
l1_warns="$(jq  '[.[] | select(.level=="warn")]  | length' <<<"$findings")"
l1_passed=true; [ "$l1_errors" = "0" ] || l1_passed=false

# ──────────────────────────────────────────────────────────────────────
# Layer 2 — portal-side marketplace-validate (opt-in)
# ──────────────────────────────────────────────────────────────────────
l2_ran=false
l2_passed=null
l2_log=""

if [ -n "$ACCOUNT" ] && [ -n "$REMOTE" ]; then
  if ! command -v hs > /dev/null 2>&1; then
    l2_log="hs CLI not installed; skipped portal-side marketplace-validate"
  else
    l2_ran=true
    tmplog="$(mktemp)"
    if hs cms theme marketplace-validate "$REMOTE" --account="$ACCOUNT" > "$tmplog" 2>&1; then
      l2_passed=true
    else
      l2_passed=false
    fi
    l2_log="$(cat "$tmplog")"
    rm -f "$tmplog"
  fi
fi

# ──────────────────────────────────────────────────────────────────────
# Emit unified report
# ──────────────────────────────────────────────────────────────────────
jq -n \
  --arg theme "$THEME" \
  --arg account "$ACCOUNT" \
  --arg remote "$REMOTE" \
  --argjson local_findings "$findings" \
  --argjson l1_passed "$l1_passed" \
  --arg     l2_passed "$l2_passed" \
  --argjson l2_ran "$l2_ran" \
  --arg     l2_log "$l2_log" \
  '{
    theme: $theme,
    account: $account,
    remote: $remote,
    local_check: { passed: $l1_passed, findings: $local_findings },
    marketplace_validate: { ran: $l2_ran, passed: ($l2_passed | fromjson? // null), log: $l2_log }
  }'

# Exit code: nonzero if any layer reported errors
if [ "$l1_passed" = "false" ]; then exit 1; fi
if [ "$l2_ran" = "true" ] && [ "$l2_passed" = "false" ]; then exit 1; fi
exit 0
