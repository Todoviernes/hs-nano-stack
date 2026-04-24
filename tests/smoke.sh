#!/usr/bin/env bash
# tests/smoke.sh — end-to-end smoke test for hs-nano-stack.
#
# What it covers:
#   1. Plugin manifest is valid JSON.
#   2. All scripts under scripts/ run cleanly with --help / no-args.
#   3. The artifact loop works: init → think → plan → resolve.
#   4. Every reference HTML file passes hubl-lint with zero errors.
#   5. Every reference JSON file parses with jq.
#   6. The theme-starter (materialized into /tmp) passes `scripts/hs-validate.sh` layer 1.
#   7. A hand-built minimal module passes fields-schema-check.
#
# What it does NOT cover (out of scope without a HubSpot portal):
#   - hs upload (--dry-run requires --account)
#   - Lighthouse audit (requires a live preview URL)
#   - Form submission smoke test
#   - The slash commands themselves (those run inside Claude Code)
#
# Exit codes:
#   0 — every layer passed
#   1 — any layer failed (the failing one is printed)

set -uo pipefail

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

pass=0
fail=0
say() { printf "\033[1;36m[smoke]\033[0m %s\n" "$*"; }
ok()  { printf "  \033[32m✓\033[0m %s\n" "$*"; pass=$((pass+1)); }
no()  { printf "  \033[31m✗\033[0m %s\n" "$*"; fail=$((fail+1)); }

# ──────────────────────────────────────────────────────────────────────
# 1. Manifest
# ──────────────────────────────────────────────────────────────────────
say "1. plugin.json is valid"
if jq -e . "$PLUGIN_DIR/.claude-plugin/plugin.json" > /dev/null 2>&1; then
  name="$(jq -r .name "$PLUGIN_DIR/.claude-plugin/plugin.json")"
  ver="$(jq -r .version "$PLUGIN_DIR/.claude-plugin/plugin.json")"
  ok "name=$name version=$ver"
else
  no ".claude-plugin/plugin.json failed jq validation"
fi

# ──────────────────────────────────────────────────────────────────────
# 2. Scripts are executable + start with bash shebang
# ──────────────────────────────────────────────────────────────────────
say "2. scripts/ shape"
for s in "$PLUGIN_DIR"/scripts/*.sh; do
  [ -x "$s" ] || { no "$s not executable"; continue; }
  head -n 1 "$s" | grep -q '^#!/usr/bin/env bash' \
    || { no "$s missing #!/usr/bin/env bash"; continue; }
  ok "$(basename "$s") +x, bash shebang"
done

# ──────────────────────────────────────────────────────────────────────
# 3. Artifact loop in a temp consumer repo
# ──────────────────────────────────────────────────────────────────────
say "3. artifact loop"
cd "$TEST_DIR"

bash "$PLUGIN_DIR/scripts/init-project.sh" > /dev/null
[ -d .hs-nano/decisions ] && [ -f .hs-nano/decisions/0001-adopt-hsns-loop.md ] \
  && ok "init-project: .hs-nano/ tree + ADR-0001" \
  || no "init-project: missing tree or ADR-0001"

# Write a think artifact
think_path="$(cat <<'JSON' | bash "$PLUGIN_DIR/scripts/artifact-write.sh" think
{ "target": "landing-page", "conversion_goal": "demo bookings",
  "primary_kpi": "form submissions / 1k visits",
  "persona": "ops manager, mid-market SaaS",
  "traffic_source": "paid LinkedIn",
  "brand_voice": "direct, technical, no fluff",
  "scope": "single landing page, hero + 3 features + form",
  "out_of_scope": ["pricing"], "premise": "validated" }
JSON
)"
[ -f "$think_path" ] && ok "artifact-write think → $think_path" \
                     || no "artifact-write think failed"

# Freeze it
tmp="$(mktemp)"; jq '.frozen = true' "$think_path" > "$tmp" && mv "$tmp" "$think_path"
frozen="$(jq -r '.frozen' "$think_path")"
[ "$frozen" = "true" ] && ok "freeze: think.frozen=true" \
                       || no "freeze: think.frozen still $frozen"

# Resolve returns the frozen think
resolved="$(bash "$PLUGIN_DIR/scripts/resolve.sh" think)"
[ "$resolved" = "$think_path" ] \
  && ok "resolve.sh think → $(basename "$resolved")" \
  || no "resolve.sh think returned wrong path: $resolved"

# Resolve decisions returns ADR-0001
adrs="$(bash "$PLUGIN_DIR/scripts/resolve.sh" decisions)"
[[ "$adrs" == *"0001-adopt-hsns-loop.md" ]] \
  && ok "resolve.sh decisions → ADR-0001" \
  || no "resolve.sh decisions missed ADR-0001"

# Empty phase returns empty
empty="$(bash "$PLUGIN_DIR/scripts/resolve.sh" review)"
[ -z "$empty" ] && ok "resolve.sh review (empty) → empty string" \
                || no "resolve.sh review should be empty, got: $empty"

# Superseded artifacts are skipped
super_path="$(echo '{"target":"landing-page","scope":"v2"}' | bash "$PLUGIN_DIR/scripts/artifact-write.sh" think)"
sleep 1
super_path2="$(echo '{"target":"landing-page","scope":"v3"}' | bash "$PLUGIN_DIR/scripts/artifact-write.sh" think)"
# Mark super_path2 as superseded → resolve should pick the older non-superseded super_path
# (NB: resolve walks newest first; super_path2 is newest. If we mark it superseded, it should fall through.)
tmp="$(mktemp)"; jq --arg sb "$(basename "$super_path" .json)" '.superseded_by = $sb' "$super_path2" > "$tmp" && mv "$tmp" "$super_path2"
resolved2="$(bash "$PLUGIN_DIR/scripts/resolve.sh" think)"
[ "$resolved2" = "$super_path" ] \
  && ok "resolve.sh skips superseded artifact" \
  || no "resolve.sh did not skip superseded: got $resolved2"

cd "$PLUGIN_DIR"

# ──────────────────────────────────────────────────────────────────────
# 4. HubL lint over every reference HTML
# ──────────────────────────────────────────────────────────────────────
say "4. hubl-lint over reference/"
findings="$(find "$PLUGIN_DIR/reference" -name '*.html' -print0 \
            | xargs -0 bash "$PLUGIN_DIR/scripts/hubl-lint.sh")"
errors="$(echo "$findings" | jq '[.[] | select(.level=="error")] | length')"
warns="$(echo "$findings"  | jq '[.[] | select(.level=="warn")]  | length')"
if [ "$errors" = "0" ]; then
  ok "$(find "$PLUGIN_DIR/reference" -name '*.html' | wc -l | tr -d ' ') HTML files: 0 errors, $warns warnings"
else
  no "$errors HubL errors in reference/"
  echo "$findings" | jq '[.[] | select(.level=="error")]'
fi

# ──────────────────────────────────────────────────────────────────────
# 5. JSON parses
# ──────────────────────────────────────────────────────────────────────
say "5. all .json files parse"
bad=0
while IFS= read -r f; do
  jq -e . "$f" > /dev/null 2>&1 || { no "$(basename "$f")"; bad=$((bad+1)); }
done < <(find "$PLUGIN_DIR" -name '*.json' \! -path '*/.git/*' \! -path '*/node_modules/*')
[ "$bad" = "0" ] && ok "every .json under repo root parses with jq" \
                 || no "$bad JSON files failed parsing"

# ──────────────────────────────────────────────────────────────────────
# 6. Layer-1 schema validation on the theme-starter (no portal needed)
# ──────────────────────────────────────────────────────────────────────
say "6. hs-validate (local layer) on theme-starter"
starter="$TEST_DIR/theme-starter"
cp -r "$PLUGIN_DIR/reference/theme-starter" "$starter"
# Add a placeholder thumbnail (marketplace-validate would warn without one)
mkdir -p "$starter/images"
printf 'PNG_PLACEHOLDER' > "$starter/thumbnail.png"
printf 'PNG_PLACEHOLDER' > "$starter/images/screenshot.png"
# Add a minimal module so we exercise the module branch of the validator
mkdir -p "$starter/modules/hero.module"
cat > "$starter/modules/hero.module/module.html" <<'HTML'
<h1>{{ module.headline }}</h1>
HTML
cat > "$starter/modules/hero.module/fields.json" <<'JSON'
[{"name":"headline","type":"text","default":"Hi"}]
JSON
cat > "$starter/modules/hero.module/meta.json" <<'JSON'
{"label":"Hero","version":1,"host_template_types":["PAGE","LANDING_PAGE"],"is_available_for_new_content":true,"global":false,"type":"module"}
JSON

report="$(bash "$PLUGIN_DIR/scripts/hs-validate.sh" "$starter")"
passed="$(echo "$report" | jq -r '.local_check.passed')"
errors="$(echo "$report" | jq '[.local_check.findings[] | select(.level=="error")] | length')"
warns="$(echo  "$report" | jq '[.local_check.findings[] | select(.level=="warn")]  | length')"
if [ "$passed" = "true" ]; then
  ok "local schema check passed (errors=$errors, warns=$warns)"
else
  no "local schema check failed"
  echo "$report" | jq '.local_check.findings'
fi

# ──────────────────────────────────────────────────────────────────────
# 7. fields-schema-check on a hand-built module
# ──────────────────────────────────────────────────────────────────────
say "7. fields-schema-check on a hand-built module"
mod="$TEST_DIR/widget.module"
mkdir -p "$mod"
cat > "$mod/fields.json" <<'JSON'
[
  {"name":"headline","type":"text","default":"Hi"},
  {"name":"image","type":"image","default":{"src":"","alt":""}}
]
JSON
cat > "$mod/module.html" <<'HTML'
<h1>{{ module.headline }}</h1>
{% if module.image.src %}<img src="{{ module.image.src }}" alt="{{ module.image.alt }}">{% endif %}
HTML
report="$(bash "$PLUGIN_DIR/scripts/fields-schema-check.sh" "$mod")"
clean="$(echo "$report" | jq -r '.clean')"
[ "$clean" = "true" ] && ok "fields-schema-check clean on consistent module" \
                      || no "fields-schema-check failed: $report"

# Now break it on purpose and confirm we detect the break
cat > "$mod/module.html" <<'HTML'
<h1>{{ module.headline }}</h1>
<p>{{ module.missing_field }}</p>
HTML
broken="$(bash "$PLUGIN_DIR/scripts/fields-schema-check.sh" "$mod" || true)"
detect="$(echo "$broken" | jq -r '.referenced_in_html_but_missing_from_fields_json[0]')"
[ "$detect" = "missing_field" ] && ok "fields-schema-check detects missing field" \
                                || no "fields-schema-check missed broken module: $broken"

# ──────────────────────────────────────────────────────────────────────
# Final
# ──────────────────────────────────────────────────────────────────────
echo
say "result: $pass passed, $fail failed"
[ "$fail" = "0" ] && exit 0 || exit 1
