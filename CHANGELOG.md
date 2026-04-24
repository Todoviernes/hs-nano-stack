# Changelog

All notable changes to this plugin are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning follows [SemVer](https://semver.org/).

## [Unreleased]

## [0.2.0] — 2026-04-24

### Added

- HubSpot Developer MCP integration (opt-in, user-side via `hs mcp setup --client claude`).
- New skill `skills/hubspot-mcp/SKILL.md` cataloging all 19 HubSpot MCP tools (documentation, projects, account, CMS) with the right-phase-to-use-from decision tree.
- `docs/MCP-SETUP.md` — one-page setup + verification + troubleshooting guide.
- Opportunistic MCP wiring in `/hsns:think`, `/hsns:nano`, `/hsns:build`, `/hsns:review`: prefer `mcp__hubspot__search-docs` / `mcp__hubspot__fetch-doc` over training-data lookups; offer `mcp__hubspot__create-cms-module` / `create-cms-template` as an alternative scaffold path for React modules or canonical-pattern requests; `mcp__hubspot__create-test-account` for one-command sandbox provisioning.
- README "Install" section now documents the optional MCP setup as the recommended third install step.

### Changed

- HubSpot CLI requirement bumped to **8.2.0+** (required for `hs mcp setup`). Earlier 7.x still works for everything except the MCP integration.
- `hs theme validate` references replaced with `scripts/hs-validate.sh` (two-layer validator: local schema + opt-in portal-side `hs cms theme marketplace-validate`). The CLI never had a `hs theme validate <local-dir>` command; v0.1 docs implied one.
- `hs upload` / `--mode=` references replaced with modern `hs cms upload` / `--cms-publish-mode=`.

### Fixed

- `agents/hs-conversion-reviewer.md` YAML frontmatter parse error (colon-space inside backticks). The agent now loads with full metadata; previously it loaded with empty frontmatter (caught by the official `claude plugins validate`).
- `scripts/hubl-lint.sh` no longer dies silently on `set -euo pipefail` + `grep` no-matches; rewritten with safer command substitution.
- `scripts/fields-schema-check.sh` now uses POSIX-friendly regex (BSD/macOS `sed` doesn't grok `\b`).
- `.claude-plugin/marketplace.json` schema corrected (the validator rejects root-level `$schema` and `description`).

## [0.1.0] — 2026-04-24

### Added

- Plugin skeleton (`.claude-plugin/plugin.json`, `commands/`, `skills/`, `agents/`, `scripts/`, `reference/`).
- Seven phase-gated commands: `/hsns:think`, `/hsns:nano`, `/hsns:build`, `/hsns:review`, `/hsns:security`, `/hsns:qa`, `/hsns:ship`. Plus `/hsns:feature` (additive, skips think) and `/hsns:help`.
- Knowledge-floor skills: `hubl-syntax`, `hubspot-theme`, `hubspot-modules`, `hubspot-templates`, `hubspot-fields-schema`, `hubspot-cli-deploy`.
- Quality skills: `hubl-security`, `hubspot-conversion`, `hubspot-email`, `hubspot-performance`, `hubspot-accessibility`.
- Specialized agents: `hs-architect`, `hs-hubl-reviewer`, `hs-schema-validator`, `hs-perf-reviewer`, `hs-conversion-reviewer`, `hs-security-reviewer`.
- Shell helpers under `scripts/`: `resolve.sh`, `artifact-write.sh`, `init-project.sh`, `hubl-lint.sh`, `fields-schema-check.sh`, `hs-validate.sh`, `lighthouse-mobile.sh`.
- Reference content: artifact schema, HubL cheatsheet, HubSpot CLI setup guide, module recipes (hero-split, feature-grid, cta-banner, form-stack), landing template (lead-capture), email template (promotional), and a complete theme starter under `reference/theme-starter/`.
- Anti-drift loop: frozen upstream artifacts, change-request flow under `.hs-nano/change-requests/`, ADR log under `.hs-nano/decisions/`.
- Versioning + branching rules in `docs/CONTRIBUTING.md`.

### Known limitations

- No HubSpot serverless functions / private apps support.
- Email QA is structural only (no Litmus / Email-on-Acid cross-client rendering).
- No `/conductor` parallel-agent orchestration.
- No `/compound` solution graduation pipeline.
- No `guard/rules.json` six-tier safety layer.
- No multi-portal deployment matrix.
- No marketplace-submission packaging metadata.

[Unreleased]: https://github.com/santiagovallejoc/hs-nano-stack/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/santiagovallejoc/hs-nano-stack/releases/tag/v0.1.0
