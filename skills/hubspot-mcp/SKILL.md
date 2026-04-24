---
name: HubSpot Developer MCP
description: Use when interacting with HubSpot's Developer MCP server — 19 tools covering documentation search, project scaffolding, validation, deployment, CMS template/module/function creation, and test-account provisioning. Companion to /hsns commands; replaces several shell-out paths and ends "agent guesses HubL from training data" failures via search-docs / fetch-doc.
version: 1.0.0
---

# HubSpot Developer MCP

HubSpot ships an official MCP server (`hs mcp`) that exposes 19 tools to AI agents. This skill lists every tool, its arguments, and the right phase to use it from. Once the user runs `hs mcp setup --client=claude` (one-time, see `docs/MCP-SETUP.md`), the tools appear as `mcp__hubspot__<tool-name>` in any Claude Code session.

> Requires HubSpot CLI **8.2.0+**. v8.5.0 confirmed working.

## Tool catalog

### Documentation & guidance (3 tools)

These are the **most valuable** for hsns — they replace training-data lookups with authoritative real-time HubSpot docs. Use them before guessing.

| Tool | What it does | Required args |
|---|---|---|
| `mcp__hubspot__search-docs` | Searches HubSpot's developer documentation; returns relevant pages with URLs. | `docsSearchQuery` |
| `mcp__hubspot__fetch-doc` | Fetches the full content of a HubSpot developer doc page. | `docUrl` |
| `mcp__hubspot__guided-walkthrough-cli` | Step-by-step help for `hs init`, `hs auth`, `hs project create`, `hs project upload`. | `command` |

**When to use in /hsns commands:**
- `/hsns:think` and `/hsns:nano` — `search-docs` for current best practices on landing pages, theme structure, email tokens. Avoid training-data drift.
- `/hsns:build` — `fetch-doc` on a specific HubL filter or field-type page if a recipe needs a tweak.
- `/hsns:review` — `fetch-doc` to confirm a HubL feature exists before flagging an "unrecognized filter."
- `/hsns:help` — `guided-walkthrough-cli` for setup questions.

### Developer projects — apps & private apps (8 tools)

These target HubSpot **Projects** (apps, private apps, UI extensions). They're **out of scope for hsns v0.1** (CMS-only), but listed for v0.2+ planning.

| Tool | What it does | Required args |
|---|---|---|
| `mcp__hubspot__create-project` | Scaffolds a new HubSpot developer project. | `destination`, `projectBase` |
| `mcp__hubspot__add-feature-to-project` | Adds features to existing projects (platform v2025.2+). | `absoluteProjectPath`, `addApp` |
| `mcp__hubspot__validate-project` | Validates project configuration locally without uploading. | `absoluteProjectPath` |
| `mcp__hubspot__upload-project` | Uploads (builds) a local project to HubSpot. | `absoluteProjectPath`, `uploadMessage` |
| `mcp__hubspot__deploy-project` | Deploys a previously uploaded build to the connected account. | `absoluteProjectPath`, `buildNumber` |
| `mcp__hubspot__get-build-status` | Retrieves build status and error messages. | `absoluteProjectPath` |
| `mcp__hubspot__get-build-logs` | Retrieves full pipeline logs for a specific build. | `absoluteProjectPath`, `buildId` |
| `mcp__hubspot__get-feature-config-schema` | Returns JSON schema for feature configuration files. | `platformVersion`, `featureType` |

> **Not used by hsns v0.1.** When v0.2 adds private-app / serverless-function support, `validate-project`, `upload-project`, `get-build-status`, and `get-build-logs` will be wired into the corresponding phases.

### Account & apps (3 tools)

| Tool | What it does | Required args |
|---|---|---|
| `mcp__hubspot__create-test-account` | Creates a temporary HubSpot developer test account (sandbox). | `name` |
| `mcp__hubspot__get-applications-info` | Lists all HubSpot apps registered in the connected account. | none |
| `mcp__hubspot__get-api-usage-patterns-by-app-id` | API usage analytics for an app. | `appId` |

**When to use:**
- **`create-test-account` is huge** for Layer-3 testing of hsns. Eliminates the manual "go to HubSpot UI → create sandbox" step. `commands/help.md` should suggest it for first-time setup.

### CMS tools (5 tools)

These are the **direct overlap with hsns**.

| Tool | What it does | Required args |
|---|---|---|
| `mcp__hubspot__create-cms-template` | Creates a new HubSpot CMS template (page, landing-page, blog, email, system). | `userSuppliedName` |
| `mcp__hubspot__create-cms-module` | Creates a CMS module (HubL or React, with content-type targeting). | `userSuppliedName`, `moduleLabel` |
| `mcp__hubspot__create-cms-function` | Creates a CMS serverless function. | `functionsFolder`, `filename`, `endpointPath` |
| `mcp__hubspot__get-cms-serverless-function-logs` | Retrieves production logs for a deployed CMS serverless function. | `endpoint` |
| `mcp__hubspot__list-cms-serverless-functions` (deprecated) | Legacy listing tool. | — |

**When to use in hsns:**

- `/hsns:build` — **two scaffolding paths:**
  - **Recipe path (default):** copy from `reference/module-recipes/` — full control over copy, CSS, brand voice; deterministic; reviewable in PR diffs.
  - **MCP path (alternative):** `create-cms-module` produces HubSpot's official starter shape — useful when the user wants the canonical pattern over our recipes, or when scaffolding a module type our recipes don't cover yet (e.g., React modules).
  - Pick **MCP path** when: the brief asks for a React module, or hsns recipes don't have a matching pattern.
  - Pick **recipe path** otherwise — our recipes embed the brand-voice and a11y discipline `/hsns:review` expects.

- `/hsns:build` for serverless functions — `create-cms-function` is the only path (we have no recipe). Out of scope for v0.1.

- `/hsns:qa` for serverless logs — `get-cms-serverless-function-logs` lets QA fetch logs after a function deploy. Out of scope for v0.1.

## Decision tree: which tool to reach for

```
Need to look up a HubSpot fact (filter, field type, tag)?
  → mcp__hubspot__search-docs
  → if found, mcp__hubspot__fetch-doc on the URL
  → never guess from training data

Need to scaffold a CMS module/template?
  → recipes in reference/* (default — controlled, brand-voiced)
  → mcp__hubspot__create-cms-{template,module} (alternative — canonical, React-capable)

Need a sandbox portal for QA?
  → mcp__hubspot__create-test-account name="hsns-sandbox"
  → then `hs accounts use hsns-sandbox`

Need to build/deploy a HubSpot Project (app)?
  → mcp__hubspot__validate-project + upload-project + deploy-project
  → (v0.2+ scope; not yet wired)

Working with CMS theme/landing/email?
  → hs cms upload + scripts/hs-validate.sh (no MCP equivalent for theme upload)
```

## Graceful degradation

The MCP server is **opt-in**. If the user hasn't run `hs mcp setup --client=claude`, `mcp__hubspot__*` tools won't be available. Every command body that references an MCP tool MUST also have a fallback:

```
1. Try mcp__hubspot__search-docs for the latest filter docs.
   If unavailable, fall back to reference/hubl-cheatsheet.md and the
   official URL https://developers.hubspot.com/docs/cms/hubl.
```

This keeps hsns usable for users who skip the MCP install.

## Setup

One-time, user-side:

```bash
# 1. Upgrade hs CLI to 8.2.0+
npm install -g @hubspot/cli@latest
hs --version

# 2. Run the MCP setup wizard
hs mcp setup --client claude

# 3. Restart Claude Code so it picks up the new MCP config.

# 4. Verify in Claude Code: ToolSearch for "hubspot" should list mcp__hubspot__*
```

Full guide: `docs/MCP-SETUP.md`.
