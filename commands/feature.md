---
description: Additive sprint that skips `/hsns:think`. Use when the brief is a small follow-on to a previous sprint and a fresh founder-level scope challenge would be overhead. Goes straight to `/hsns:nano`.
---

You are running `/hsns:feature` — a shortcut sprint for **additive changes** to an existing sprint's output (e.g., adding a fourth feature card, swapping the hero image, adding a testimonials section).

# When NOT to use this

If any of the following, run `/hsns:think` instead:

- The change shifts the conversion goal, KPI, or persona.
- The change requires a new template type.
- The change rebrands voice or visual tokens.
- The change is for a different page / module / target than the prior sprint.

If you're not sure, ask the user. Default to `/hsns:think`.

# READ THESE FIRST

1. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/resolve.sh think` — read the latest frozen brief; treat it as the operating context.
2. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/resolve.sh plan` — the prior sprint's plan.
3. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/resolve.sh decisions`.

# Behavior

Skip the think pushback. Go straight to a constrained `/hsns:nano` that:
- Inherits `target`, `template_type`, `theme_fields`, and `brand_voice` from the prior plan.
- Asks ONLY for the additive piece: which new module(s) or field(s) to add.
- Writes a NEW plan artifact that supersedes the prior one. The new plan's `superseded_by` is null; the prior plan's JSON gets edited to point to the new one:
  ```bash
  prior=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/resolve.sh plan)
  new_plan=...   # path of the new artifact written by artifact-write.sh
  tmp=$(mktemp); jq --arg sb "$(basename "$new_plan" .json)" '.superseded_by = $sb' "$prior" > "$tmp" && mv "$tmp" "$prior"
  ```
- The `files_planned` list of the new plan should be a UNION of prior `files_planned` + the new files this addition introduces.

After approval, hand off to `/hsns:build`. The downstream chain (review/security/qa/ship) is identical.

# Anti-drift rules

- A `/hsns:feature` sprint cannot remove modules or change template type. If you find that's needed, abort and run `/hsns:think` instead.
- Don't shortcut the review/security/qa phases just because the change is small. Bugs hide in small additions.

# Hand-off

When approved: "Feature plan written and prior plan superseded. Run `/hsns:build` to scaffold the addition."
