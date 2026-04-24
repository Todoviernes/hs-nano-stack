#!/usr/bin/env bash
# resolve.sh — find the latest non-superseded artifact for a given phase.
#
# Usage:
#   scripts/resolve.sh think         # prints path to latest .hs-nano/think/*.json (or empty)
#   scripts/resolve.sh plan
#   scripts/resolve.sh review
#   scripts/resolve.sh security
#   scripts/resolve.sh qa
#   scripts/resolve.sh ship
#   scripts/resolve.sh decisions     # prints all accepted ADRs, newest first
#
# Exits 0 always (empty output if no artifact exists). Consumers should test
# `[ -n "$(scripts/resolve.sh think)" ]` to detect "no artifact yet."

set -euo pipefail

PHASE="${1:-}"
ROOT="${HSNS_ARTIFACT_ROOT:-.hs-nano}"

if [ -z "$PHASE" ]; then
  echo "usage: resolve.sh <phase>" >&2
  exit 2
fi

case "$PHASE" in
  decisions)
    if [ -d "$ROOT/decisions" ]; then
      # Newest first. Filter to accepted (status line) only.
      find "$ROOT/decisions" -maxdepth 1 -type f -name '*.md' -print0 \
        | xargs -0 grep -l -E '^- \*\*Status:\*\* Accepted' 2>/dev/null \
        | sort -r
    fi
    ;;
  think|plan|review|security|qa|ship)
    if [ -d "$ROOT/$PHASE" ]; then
      # Newest first by filename (timestamp prefix).
      latest="$(find "$ROOT/$PHASE" -maxdepth 1 -type f -name '*.json' 2>/dev/null \
                  | sort -r | head -n 50)"

      # Walk newest→oldest, return first one that is NOT superseded by another.
      for f in $latest; do
        if command -v jq >/dev/null 2>&1; then
          superseded="$(jq -r '.superseded_by // empty' "$f" 2>/dev/null || true)"
          if [ -n "$superseded" ]; then
            continue
          fi
        fi
        echo "$f"
        exit 0
      done
    fi
    ;;
  *)
    echo "unknown phase: $PHASE" >&2
    exit 2
    ;;
esac
