#!/usr/bin/env bash
# lighthouse-mobile.sh — documented-interface helper for /hsns:qa.
#
# This script does NOT spawn a browser itself. The QA command (commands/qa.md)
# uses Chrome DevTools MCP tools available in the Claude Code session:
#
#   mcp__plugin_chrome-devtools-mcp_chrome-devtools__new_page
#   mcp__plugin_chrome-devtools-mcp_chrome-devtools__navigate_page
#   mcp__plugin_chrome-devtools-mcp_chrome-devtools__lighthouse_audit
#   mcp__plugin_chrome-devtools-mcp_chrome-devtools__take_screenshot
#   mcp__plugin_chrome-devtools-mcp_chrome-devtools__list_console_messages
#
# This helper only prints a JSON template for the agent to fill in with the
# actual lighthouse_audit MCP response. Keeps the QA artifact shape consistent.
#
# Usage:
#   scripts/lighthouse-mobile.sh <preview-url>

set -euo pipefail

URL="${1:-}"

if [ -z "$URL" ]; then
  echo '{"error":"preview URL required"}' >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo '{"error":"jq required"}' >&2
  exit 2
fi

# Empty template — the agent fills it in after running the MCP audit.
jq -n --arg url "$URL" '{
  url: $url,
  device: "mobile",
  scores: {
    performance: null,
    accessibility: null,
    best_practices: null,
    seo: null
  },
  core_web_vitals: {
    lcp_seconds: null,
    cls: null,
    inp_milliseconds: null,
    fcp_seconds: null,
    tbt_milliseconds: null
  },
  failed_audits: [],
  notes: "Fill in from mcp__plugin_chrome-devtools-mcp_chrome-devtools__lighthouse_audit response."
}'
