# Optional: HubSpot Developer MCP setup

`hs-nano-stack` works **without** HubSpot's MCP server. Adding it gives the agent 19 extra tools — most importantly **`search-docs`** and **`fetch-doc`**, which let any phase look up authoritative HubSpot docs at runtime instead of guessing from training data. Highly recommended.

## Prerequisites

- HubSpot CLI **8.2.0 or newer** (`hs --version`).
  - Upgrade: `npm install -g @hubspot/cli@latest`.
- A HubSpot account (any tier, including free).
- Claude Code installed.

## One-time setup (per machine)

```bash
hs mcp setup --client claude
```

This walks an interactive flow:
1. Confirms the target client (Claude Code in this case).
2. Writes the MCP server config into Claude Code's user settings.
3. Confirms HubSpot account auth (uses the same `hubspot.config.yml` PAK as the rest of `hs`).

After completion, **restart Claude Code** so it picks up the new MCP config.

## Verifying it worked

In a fresh Claude Code session, you can query for available MCP tools. They appear under the `mcp__hubspot__*` namespace:

```
mcp__hubspot__search-docs        — search HubSpot developer docs
mcp__hubspot__fetch-doc          — fetch a specific doc page
mcp__hubspot__create-cms-module  — scaffold a CMS module
mcp__hubspot__create-test-account — provision a sandbox portal
…
```

Full catalog: `skills/hubspot-mcp/SKILL.md`.

## What changes when MCP is enabled

The hsns commands have **opportunistic** MCP integration — they use the tools when available and fall back to shell + recipes when not. Specifically:

| Phase | With MCP | Without MCP |
|---|---|---|
| `/hsns:think` | `search-docs` confirms current best practices for the brief's traffic source / persona. | Skill knowledge only. |
| `/hsns:nano` | `search-docs` confirms field-type catalog and template-type semantics. | `skills/hubspot-fields-schema` + cheatsheet. |
| `/hsns:build` | Optional: `create-cms-template` / `create-cms-module` for canonical/React scaffolds. | `reference/module-recipes/` + `reference/theme-starter/`. |
| `/hsns:review` | `fetch-doc` to confirm HubL filter validity before flagging. | `scripts/hubl-lint.sh` + cheatsheet. |
| `/hsns:qa` | `get-cms-serverless-function-logs` for function diagnostics (v0.2+). | shell-only. |
| Setup | `create-test-account` provisions a sandbox in seconds. | Manual: HubSpot UI → Account Setup → Sandbox. |

## Skipping MCP

Plugin still works fine without it. The trade-off: phases lean on training-data + reference content rather than authoritative real-time lookups. Recipes stay the same; QA still runs Lighthouse; ship still uploads via `hs cms upload`.

## Troubleshooting

| Symptom | Likely cause | Resolution |
|---|---|---|
| `hs mcp setup` not found | CLI < 8.2.0. | `npm install -g @hubspot/cli@latest`. |
| `mcp__hubspot__*` tools not visible | Claude Code wasn't restarted after `hs mcp setup`. | Restart. |
| MCP setup writes to the wrong client | Used `--client codex` etc. by mistake. | Re-run with `--client claude`. |
| `search-docs` returns empty | Not authenticated. | `hs init` or `hs auth` to configure a portal first. |
| Tool calls hit rate limits | Heavy use during a single sprint. | The CLI handles backoff; if persistent, file an issue with HubSpot. |

## Removing MCP

If you want to undo:
1. Open `~/.claude/settings.json` (or `~/.claude/<client>/settings.json` depending on Claude Code version).
2. Remove the `mcpServers.hubspot-developer` (or similarly named) entry.
3. Restart Claude Code.

The hsns plugin will continue to work without the MCP tools.
