#!/usr/bin/env bash
# artifact-write.sh — write a phase artifact JSON with a timestamped filename.
#
# Reads JSON from stdin, validates with jq, and writes to:
#   .hs-nano/<phase>/<UTC-ISO-8601>.json
#
# Adds: phase, timestamp, schema_version, frozen (default false) — only if the
# input doesn't already set them.
#
# Usage:
#   echo '{"target":"landing-page", ...}' | scripts/artifact-write.sh think
#   scripts/artifact-write.sh plan < my-plan.json

set -euo pipefail

PHASE="${1:-}"
ROOT="${HSNS_ARTIFACT_ROOT:-.hs-nano}"
SCHEMA_VERSION="1"

if [ -z "$PHASE" ]; then
  echo "usage: artifact-write.sh <phase>" >&2
  exit 2
fi

case "$PHASE" in
  think|plan|review|security|qa|ship|change-requests) ;;
  *)
    echo "unknown phase: $PHASE" >&2
    exit 2 ;;
esac

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required (brew install jq)" >&2
  exit 3
fi

mkdir -p "$ROOT/$PHASE"

ts="$(date -u +%Y%m%dT%H%M%SZ)"
out="$ROOT/$PHASE/${ts}.json"

# Read stdin → enrich with defaults → write atomically.
tmp="$(mktemp)"
jq --arg phase "$PHASE" \
   --arg ts "$ts" \
   --arg schema "$SCHEMA_VERSION" \
   '
   . as $in
   | {
       phase: ($in.phase // $phase),
       timestamp: ($in.timestamp // $ts),
       schema_version: ($in.schema_version // ($schema | tonumber)),
       frozen: ($in.frozen // false)
     } + $in
   ' > "$tmp"

mv "$tmp" "$out"
echo "$out"
