#!/usr/bin/env bash
# init-project.sh — bootstrap a HubSpot content repo to use hs-nano-stack.
#
# Idempotent. Run from the repo root. Does:
#   - Creates .hs-nano/ directory tree.
#   - Creates .hs-nano/decisions/ with a starter ADR-0001.
#   - Adds .gitignore entries for hubspot.config.yml and the artifact cache.
#   - Drops a placeholder hubspot.config.yml.example so devs see what to fill in.
#   - Creates an empty hubspot.config.yml IF the user explicitly opts in (--with-config).
#
# Usage:
#   scripts/init-project.sh                  # safe, no secrets touched
#   scripts/init-project.sh --with-config    # also creates an empty hubspot.config.yml stub

set -euo pipefail

ROOT="${HSNS_ARTIFACT_ROOT:-.hs-nano}"

mkdir -p \
  "$ROOT/think" \
  "$ROOT/plan" \
  "$ROOT/build" \
  "$ROOT/review" \
  "$ROOT/security" \
  "$ROOT/qa" \
  "$ROOT/ship" \
  "$ROOT/change-requests" \
  "$ROOT/decisions" \
  "$ROOT/journal" \
  "$ROOT/tmp" \
  "$ROOT/artifacts/cache"

# .gitignore — append only if missing.
touch .gitignore
add_gi() {
  if ! grep -qxF "$1" .gitignore; then
    echo "$1" >> .gitignore
  fi
}
add_gi "# hs-nano-stack — added by scripts/init-project.sh"
add_gi "hubspot.config.yml"
add_gi "hubspot.config.yaml"
add_gi "${ROOT}/artifacts/cache/"
add_gi "${ROOT}/tmp/"
add_gi ".env"
add_gi ".DS_Store"
add_gi "node_modules/"
add_gi "*.log"

# Starter ADR — only if no decisions exist yet.
if [ -z "$(ls -A "$ROOT/decisions" 2>/dev/null)" ]; then
  cat > "$ROOT/decisions/0001-adopt-hsns-loop.md" <<'EOF'
# ADR 0001 — Adopt the hs-nano-stack phase-gated loop

- **Status:** Accepted
- **Date:** 2026-04-24

## Context
We are building HubSpot CMS Hub content (themes, landings, modules, emails) and want to avoid the three predictable failure modes of generalist AI agents on HubSpot: HubL syntax errors, schema drift across `theme.json`/`fields.json`/`meta.json`, and skipped Core-Web-Vitals/marketplace gates.

## Decision
Adopt the seven-phase `hs-nano-stack` workflow (`/hsns:think → nano → build → review → security → qa → ship`) with frozen upstream artifacts, change-request flow, and ADR log discipline.

## Consequences
- Every change has a written audit trail under `.hs-nano/`.
- Drift detection is structural, not behavioral — review reads the frozen plan.
- Onboarding new agents/sessions is fast: read the latest non-superseded artifacts and the accepted ADRs.

## Alternatives considered
- A free-form agent prompt — rejected: drift is the default mode without phase gates.
- A standalone CLI port of nanostack — rejected for v0.1 to ship faster; revisit later.
EOF
  echo "wrote $ROOT/decisions/0001-adopt-hsns-loop.md"
fi

# hubspot.config.yml.example — never overwritten.
if [ ! -f hubspot.config.yml.example ]; then
  cat > hubspot.config.yml.example <<'EOF'
defaultPortal: sandbox
portals:
  - name: sandbox
    portalId: 0000000
    authType: personalaccesskey
    personalAccessKey: REPLACE_ME_FROM_HUBSPOT_SETTINGS
  - name: prod
    portalId: 0000001
    authType: personalaccesskey
    personalAccessKey: REPLACE_ME_FROM_HUBSPOT_SETTINGS
EOF
  echo "wrote hubspot.config.yml.example (do not commit a real one)"
fi

# Optional: empty config stub — only with --with-config flag.
if [ "${1:-}" = "--with-config" ] && [ ! -f hubspot.config.yml ]; then
  cp hubspot.config.yml.example hubspot.config.yml
  echo "wrote hubspot.config.yml stub — fill in your portal IDs + access keys"
  echo "  (already added to .gitignore — never commit this file)"
fi

echo
echo "hs-nano-stack initialized."
echo "Next: run /hsns:think in Claude Code to scope your first sprint."
