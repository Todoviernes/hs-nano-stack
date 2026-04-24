#!/usr/bin/env bash
# hubl-lint.sh — minimal HubL syntax linter. Catches the top-N footguns:
#   1. Unbalanced {% %} or {{ }}.
#   2. Use of `|safe` filter on a module.* var (XSS-prone heuristic).
#
# Output: JSON array of findings. Empty array means clean.
# Exit code: 0 always (linting findings are data, not failures).
#
# Usage:
#   scripts/hubl-lint.sh path/to/module.html [more files...]

set -uo pipefail

if [ "$#" -lt 1 ]; then
  echo "usage: hubl-lint.sh <file> [<file> ...]" >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo '[]'
  echo "warn: jq not installed, skipping HubL lint" >&2
  exit 0
fi

# Count occurrences of a literal pattern in a file.
count_pat() {
  local pat="$1" file="$2"
  local n
  n="$(grep -o -F "$pat" "$file" 2>/dev/null | wc -l | tr -d ' ')"
  echo "${n:-0}"
}

findings_json='[]'

add_finding() {
  local rule="$1" level="$2" file="$3" message="$4"
  findings_json="$(jq --arg rule "$rule" --arg level "$level" --arg file "$file" --arg msg "$message" \
    '. + [{rule: $rule, level: $level, file: $file, message: $msg}]' <<<"$findings_json")"
}

for f in "$@"; do
  if [ ! -f "$f" ]; then
    add_finding "file-missing" "error" "$f" "file not found"
    continue
  fi

  open_block="$(count_pat '{%' "$f")"
  close_block="$(count_pat '%}' "$f")"
  open_expr="$(count_pat '{{' "$f")"
  close_expr="$(count_pat '}}' "$f")"

  if [ "$open_block" != "$close_block" ]; then
    add_finding "unbalanced-block-tag" "error" "$f" "$open_block {% vs $close_block %}"
  fi
  if [ "$open_expr" != "$close_expr" ]; then
    add_finding "unbalanced-expression-tag" "error" "$f" "$open_expr {{ vs $close_expr }}"
  fi

  # |safe on a module.* var.
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    add_finding "safe-filter-on-module-var" "warn" "$f" \
      "|safe on user-editable field is XSS-prone — only use after explicit sanitization: $line"
  done < <(grep -nE '\{\{[^}]*\bmodule\.[a-zA-Z0-9_]+[^}]*\|\s*safe' "$f" 2>/dev/null || true)
done

echo "$findings_json"
