---
description: Quick reference for the hs-nano-stack plugin — the seven phases, where artifacts live, how to set up the HubSpot CLI, and the anti-drift loop.
---

# `hs-nano-stack` — quick reference

## The seven phases

```
/hsns:think  →  /hsns:nano  →  /hsns:build  →  /hsns:review  →  /hsns:security  →  /hsns:qa  →  /hsns:ship
```

| Phase | Role | Reads | Writes |
|---|---|---|---|
| `/hsns:think` | CRO/marketer challenges scope | (decisions) | `.hs-nano/think/<TS>.json` |
| `/hsns:nano` | Eng-manager spec | think + decisions | `.hs-nano/plan/<TS>.json` |
| `/hsns:build` | Implementation | plan + decisions | source files |
| `/hsns:review` | Staff-engineer review | plan + source | `.hs-nano/review/<TS>.json` |
| `/hsns:security` | HubL XSS, secrets, CSP, OWASP | review | `.hs-nano/security/<TS>.json` |
| `/hsns:qa` | hs validate + Lighthouse + a11y | review + security | `.hs-nano/qa/<TS>.json` |
| `/hsns:ship` | hs upload + journal + tags | review + security + qa | `.hs-nano/ship/<TS>.json` |

Plus:
- `/hsns:feature` — additive sprint, skips `/hsns:think`.
- `/hsns:help` — this card.

## Anti-drift loop

1. Each phase reads upstream artifacts via `scripts/resolve.sh`.
2. Once approved, upstream artifacts are `"frozen": true`. Downstream phases don't deviate.
3. Mid-flight scope changes go through `.hs-nano/change-requests/`.
4. Non-trivial choices land as ADRs in `.hs-nano/decisions/NNNN-slug.md`.
5. `/hsns:review` flags any file outside `plan.files_planned` as scope drift.

## Where things live

```
.hs-nano/
├── think/<TS>.json              ← scope brief
├── plan/<TS>.json               ← module map, files planned
├── review/<TS>.json             ← review findings + diff classification
├── security/<TS>.json           ← HubL XSS, secrets, CSP findings, grade A-F
├── qa/<TS>.json                 ← hs validate + Lighthouse + screenshots
├── ship/<TS>.json               ← upload result, version bumps, tag
├── change-requests/<TS>.json    ← pending mid-flight scope changes
├── decisions/NNNN-slug.md       ← ADRs (append-only)
└── journal/<TS>-<slug>.md       ← human-readable sprint summary (written on ship)
```

## HubSpot CLI

```bash
npm install -g @hubspot/cli@latest
hs init                       # one-time auth, writes hubspot.config.yml
hs accounts list              # see configured portals
hs accounts use sandbox       # set default
```

`hubspot.config.yml` is gitignored automatically — never commit it.

Full setup guide: `reference/setup-hs-cli.md`.

## Versioning + branching

- **Plugin** (`.claude-plugin/plugin.json`): SemVer, annotated tags `v<X.Y.Z>`, `CHANGELOG.md` keeps the changelog.
- **Themes** (`theme.json`): SemVer, auto-bumped by `/hsns:ship` from `review.diff_classification`.
- **Modules** (`module.meta.json`): integer, bumped on relevant change.
- **Branching (consumer repos):** trunk-based. `main` ≡ prod portal · `staging` ≡ sandbox · `feat/*` for sprints. Conventional Commits.

Full rules: `docs/CONTRIBUTING.md`.

## Scripts

All scripts ship with the plugin and are invoked via `${CLAUDE_PLUGIN_ROOT}`:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/init-project.sh                                # bootstrap a consumer repo's .hs-nano/
bash ${CLAUDE_PLUGIN_ROOT}/scripts/resolve.sh <phase>                             # latest non-superseded artifact
bash ${CLAUDE_PLUGIN_ROOT}/scripts/artifact-write.sh <phase> < input.json         # write a phase artifact
bash ${CLAUDE_PLUGIN_ROOT}/scripts/hubl-lint.sh path/to/module.html               # HubL syntax + |safe lint
bash ${CLAUDE_PLUGIN_ROOT}/scripts/fields-schema-check.sh path/to/X.module/       # fields.json ↔ HubL ref check
bash ${CLAUDE_PLUGIN_ROOT}/scripts/hs-validate.sh ./theme --account=<sandbox>     # hs theme validate + dry-run upload
bash ${CLAUDE_PLUGIN_ROOT}/scripts/lighthouse-mobile.sh <preview-url>             # template for QA artifact
```

## Common questions

**"Why not just use vanilla `/hsns:think` every time?"**
For follow-on changes inside the same sprint context, `/hsns:think` repetition is overhead. `/hsns:feature` reuses the prior brief.

**"What if I disagree with a frozen artifact?"**
Open a change request. Don't edit the JSON directly. Once a change request is approved, a new artifact is written that supersedes the prior one (which gets `superseded_by` set), preserving the audit trail.

**"What if `/hsns:review` keeps catching the same drift?"**
You're editing files outside `files_planned`. Either add them via a change request or remove them.

**"What if I need to ship to prod without QA?"**
Don't. If you really must, write an ADR (`.hs-nano/decisions/NNNN-skip-qa.md`) explaining why, and pass `--accept-qa-risk` to `/hsns:ship`. The artifact will record the override.

**"Where's the `hs` CLI documented?"**
`skills/hubspot-cli-deploy/SKILL.md` for what hsns wraps. Authoritative source: https://developers.hubspot.com/docs/cms/cli.
