# Setup the HubSpot CLI

This is the canonical onboarding doc. The plugin's `commands/help.md` and `commands/ship.md` link here. Follow the steps in order.

## 1. Install the CLI globally

```bash
# Either npm, yarn, or pnpm — pick one.
npm install -g @hubspot/cli@latest
# or
yarn global add @hubspot/cli@latest
# or
pnpm add -g @hubspot/cli@latest
```

Verify:
```bash
hs --version       # expect >= 7.0
```

If `hs` isn't found after install, your global node bin isn't on `PATH`. On macOS with nvm:
```bash
echo 'export PATH="$(npm config get prefix)/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

## 2. Get a Personal Access Key (PAK)

1. Sign in to HubSpot.
2. Navigate to **Settings** (gear icon, top right).
3. **Integrations** → **Private Apps** → **Personal access key**.
4. Click **Show key** (or generate a new one if first time).
5. Copy the value. It looks like `na1-xxxx-xxxx-xxxx-xxxx-xxxx-xxxx-xxxx`.

The PAK is a long-lived secret. Treat it like a password.

> **Permissions.** A PAK inherits the permissions of the user who generated it. For dev work on themes/landings, the user needs at minimum: Design Manager (read+write), Pages (read+write), Email Templates (if you build emails), and Forms (if you embed forms).

## 3. Initialize a portal in your repo

From the root of your HubSpot content repo (the directory you'll `hs upload` from):

```bash
cd /path/to/your/theme-or-content-repo
hs init
```

Walk-through:
- Choose **Personal access key** for auth type.
- Paste your PAK.
- Give the portal a **name** (e.g., `sandbox`, `prod`, `acme-prod`). The name is what you'll pass to `--account=`.

This writes `hubspot.config.yml` in the current directory:

```yaml
defaultPortal: sandbox
portals:
  - name: sandbox
    portalId: 1234567
    authType: personalaccesskey
    personalAccessKey: na1-xxxx-...
allowUsageTracking: false
httpTimeout: 30000
```

> **Critical security:** `hs-nano-stack`'s `scripts/init-project.sh` adds `hubspot.config.yml` to `.gitignore` automatically. Verify with `git check-ignore -v hubspot.config.yml`. Never commit a real `hubspot.config.yml`.

> Commit the `hubspot.config.yml.example` stub instead — it shows the shape without the secret.

## 4. Add a second portal (sandbox + prod is typical)

```bash
hs auth                           # walks the same flow, appends a portal
hs accounts list                  # confirm both portals
hs accounts use sandbox           # set default
```

You can also add via direct edit of `hubspot.config.yml`:
```yaml
defaultPortal: sandbox
portals:
  - name: sandbox
    portalId: 1234567
    authType: personalaccesskey
    personalAccessKey: na1-...
  - name: prod
    portalId: 7654321
    authType: personalaccesskey
    personalAccessKey: na1-...
```

## 5. Verify access

Pull HubSpot's official theme boilerplate to confirm read works:

```bash
hs fetch @hubspot/cms-theme-boilerplate ./_probe --account=sandbox
ls _probe/                        # should contain theme.json, fields.json, templates/, modules/...
rm -rf ./_probe
```

If this works, you're set up. If it fails:
- `Account not found` → `hs accounts list` to confirm portal is named correctly.
- `Invalid PAK` → regenerate in HubSpot Settings.
- `Network` → check VPN / corporate proxy.

## 6. Set up a sandbox portal (recommended)

`hs-nano-stack`'s `/hsns:qa` and `/hsns:ship` workflow upload to a **sandbox** portal first, then `--promote` to production.

If you don't have a sandbox:
- HubSpot Pro/Enterprise customers: **Settings** → **Account Setup** → **Sandbox Account** → **Create Sandbox**. Free with paid plans. Confirm the sandbox shows in the portal switcher in HubSpot.
- HubSpot Free / Starter customers: sandbox is not always available. As a workaround, use a separate free HubSpot account dedicated to dev work.

Once the sandbox exists, run `hs auth` again and add it as a portal named `sandbox`.

## 7. Common commands

> CLI 7.x uses the `hs cms ...` subtree. The older `hs upload` / `hs watch` / `hs theme` forms still work as **deprecated aliases** — they print a warning and run the new code. Prefer the `hs cms` form below.

```bash
# List portals
hs accounts list

# Use a portal
hs accounts use sandbox

# Local-only schema check (NO portal needed) — layer 1 of the validator
bash ${CLAUDE_PLUGIN_ROOT}/scripts/hs-validate.sh ./my-theme

# Watch + auto-upload (dev loop)
hs cms watch ./my-theme my-theme --account=sandbox

# Single upload
hs cms upload ./my-theme my-theme --account=sandbox

# Pull a theme/file from a portal to local
hs cms fetch my-theme ./my-theme --account=sandbox

# Local theme preview server (talks to portal for content)
hs cms theme preview --src=./my-theme --account=sandbox

# Upload a single file
hs cms upload ./my-theme/templates/landing.html my-theme/templates/landing.html --account=sandbox

# Marketplace-validate (requires the theme to ALREADY be uploaded)
hs cms theme marketplace-validate my-theme --account=sandbox
```

> **No `--dry-run` on `hs cms upload`.** The CLI doesn't expose one. Pre-upload sanity checks live in `scripts/hs-validate.sh` (layer 1 — local). The portal-side validator runs only after upload (layer 2).

## 8. Troubleshooting

| Issue | Resolution |
|---|---|
| `hs: command not found` | Verify global npm install; check PATH. |
| `Account not found` | `hs accounts list`; if missing, `hs auth`. |
| `Invalid Personal Access Key` | Regenerate in HubSpot Settings → Integrations → Private Apps. |
| `Theme not found` | First upload uses any name; subsequent uploads must match. |
| `Network timeout` | Increase `httpTimeout` in `hubspot.config.yml`; check VPN. |
| `theme.json schema invalid` | `bash ${CLAUDE_PLUGIN_ROOT}/scripts/hs-validate.sh ./my-theme` for the precise error. |
| `Cannot read property of undefined` (cli crash) | `npm i -g @hubspot/cli@latest` to upgrade; report on the [HubSpot CLI repo](https://github.com/HubSpot/hubspot-cli/issues). |
| Slow watch | The watch is per-file; large themes take a few seconds per save. Acceptable. |
| Permissions error on upload | Your PAK was issued by a user without Design Manager write permission. Regenerate with a privileged user. |

## 9. Removing a portal

```bash
hs accounts remove sandbox
```

Or delete the entry from `hubspot.config.yml`. The PAK on the HubSpot side is unchanged — to truly revoke access, regenerate the key in HubSpot Settings.

## 10. Multiple repos sharing portals

By default, `hubspot.config.yml` is per-repo (in the repo root). For a single-developer setup that uses the same portals across many repos, use a global config:

```bash
hs init --use-env       # reads HUBSPOT_PORTAL_ID + HUBSPOT_PERSONAL_ACCESS_KEY from env
# or
hs init --path=~/hubspot.config.yml
```

For team setups, **always** keep `hubspot.config.yml` per-repo and per-developer. Each developer has their own PAK.

## 11. Security checklist

- [ ] `hubspot.config.yml` in `.gitignore` (auto-added by `scripts/init-project.sh`).
- [ ] `hubspot.config.yml.example` committed (no secrets).
- [ ] PAK rotated when an employee leaves or every 6 months (HubSpot doesn't enforce; do it in your runbook).
- [ ] No PAKs in CI environment variables unless the CI service supports encrypted secrets.
- [ ] Production PAK has the minimum permissions needed (don't use a Super Admin PAK for theme uploads).
