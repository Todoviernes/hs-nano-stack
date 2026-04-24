# Changelog

All notable changes to this plugin are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning follows [SemVer](https://semver.org/).

## [Unreleased]

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
