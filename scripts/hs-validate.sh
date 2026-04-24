#!/usr/bin/env bash
# hs-validate.sh — wrap `hs theme validate` and `hs upload --dry-run` and emit
# a normalized JSON fragment for the QA phase artifact.
#
# Usage:
#   scripts/hs-validate.sh <theme-src-dir> [--account=<name>]
#
# Stdout: a JSON object suitable for embedding under qa.hs_validate_output.
# Exit codes:
#   0  all green (validate passed, dry-run upload passed)
#   1  validate or dry-run reported errors (still emits JSON)
#   2  hs CLI not installed or input bad

set -euo pipefail

THEME_SRC="${1:-}"
ACCOUNT_FLAG=""

shift || true
for arg in "$@"; do
  case "$arg" in
    --account=*) ACCOUNT_FLAG="$arg" ;;
  esac
done

if [ -z "$THEME_SRC" ] || [ ! -d "$THEME_SRC" ]; then
  echo '{"error":"theme src dir missing"}' >&2
  exit 2
fi

if ! command -v hs >/dev/null 2>&1; then
  echo '{"error":"hs CLI not installed; npm i -g @hubspot/cli@latest"}' >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo '{"error":"jq required (brew install jq)"}' >&2
  exit 2
fi

# Run `hs theme validate` (text output; we capture and parse).
validate_log="$(mktemp)"
validate_exit=0
hs theme validate "$THEME_SRC" > "$validate_log" 2>&1 || validate_exit=$?

# Run `hs upload --dry-run` if an account flag was given. Without an account,
# `hs upload` defaults to the configured default portal — we don't want to
# upload silently, so dry-run is opt-in.
upload_log="$(mktemp)"
upload_exit=255
if [ -n "$ACCOUNT_FLAG" ]; then
  upload_exit=0
  hs upload "$THEME_SRC" "$(basename "$THEME_SRC")" --dry-run "$ACCOUNT_FLAG" \
    > "$upload_log" 2>&1 || upload_exit=$?
else
  echo "no --account flag, skipping hs upload --dry-run" > "$upload_log"
fi

# Build the JSON fragment.
jq -n \
  --arg theme_src "$THEME_SRC" \
  --arg validate_log "$(cat "$validate_log")" \
  --argjson validate_exit "$validate_exit" \
  --arg upload_log "$(cat "$upload_log")" \
  --argjson upload_exit "$upload_exit" \
  --arg account_flag "$ACCOUNT_FLAG" \
  '{
    theme_src: $theme_src,
    account_flag: $account_flag,
    validate: {
      exit_code: $validate_exit,
      passed: ($validate_exit == 0),
      log: $validate_log
    },
    upload_dry_run: {
      exit_code: $upload_exit,
      passed: ($upload_exit == 0),
      ran: ($upload_exit != 255),
      log: $upload_log
    }
  }'

rm -f "$validate_log" "$upload_log"

# Exit non-zero if either step actually ran AND failed.
if [ "$validate_exit" -ne 0 ] || { [ -n "$ACCOUNT_FLAG" ] && [ "$upload_exit" -ne 0 ]; }; then
  exit 1
fi
exit 0
