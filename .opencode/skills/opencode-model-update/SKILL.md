---
name: opencode-model-update
description: Update model tiers and fallback chains in the NixOS opencode configuration (nix/modules/home/ai/opencode/default.nix) when new models are released or subscriptions change. Use when the user asks to update, swap, or upgrade opencode models, tiers, router models, or fallback models, or to check which models are newest. Do not use for general opencode config questions unrelated to model selection.
---

# Update opencode model tiers

File: `/home/roey/.dotfiles/nix/modules/home/ai/opencode/default.nix`

## Constraints (from the user)
- Only edit the existing tiers. Do not add tiers.
- Do not add per-tier `fallbacks` to the auto-router. Failover is handled by `opencode-model-fallback` only.
- Each tier should map to a model from the provider the user subscribes to (Claude Pro, ChatGPT Plus). The user cannot see model IDs from inside the subscription, so ask before assuming availability when unsure.

## Steps
1. List the current models per provider, including release dates and context:
   - `opencode models anthropic --verbose > /tmp/opencode/anth.txt 2>&1`
   - `opencode models openai --verbose > /tmp/opencode/oai.txt 2>&1`
   - Grep the output for `"id"`, `"release_date"`, `"context"`, and variant keys. Skip `-fast`, `-ultrafast`, `-flex` variants: they are the same model on a priority tier.
2. Map models to tiers in `opencode-auto-router.json` (`tierModels`):
   - `SIMPLE`: smallest capable model (e.g. Haiku, Luna), variant `low`.
   - `MEDIUM`: mid model (e.g. Sonnet, Terra), variant `medium`.
   - `COMPLEX`: largest model in the subscription (e.g. Sol), variant `high`.
   - Only pick variants the model actually lists (check `variants` in the JSON).
3. Update the global fallback chain: `agents."*".fallbackModels` and the matching comment for the "Ordered chain" block. Use one model from each provider, so failover crosses providers.
4. Update the router display name (`provider.auto-router.models.main.name`) if the tier models changed.
5. Keep `small_model` unless the user asks to change it.
6. Verify with a Nix syntax-only check: `nix-instantiate --parse nix/modules/home/ai/opencode/default.nix`. Do not run `just dry-rebuild` or any rebuild without asking first, since they are expensive.
7. Tell the user to run `just rebuild` themselves. Note any tier that is Claude-only or OpenAI-only.

## Notes
- Router `pinSession = true`: the first prompt picks the tier for the whole session.
- Fallback cooldown is 5h (`cooldownMs`). Changing the chain does not clear in-memory health state until restart.
