// OpenCode 2 adapter for opencode-auto-router (which only ships a 1.x plugin).
//
// The routing logic itself (classifier, tiers, pinSession, notify) is the
// upstream package's own createAutoRouterWithConfig(); only the config source
// and the hook wiring are replaced. Config comes from this plugin's `options`
// in opencode.json (the same shape upstream reads from
// opencode-auto-router.json), so it is declared in Nix with the plugin entry.
//
// Hook wiring:
//
//   1.x: a "chat.message" hook rewrites output.message.model in place.
//   2.x: the "prompt" hook cannot change the model, so feed the upstream
//        handler a 1.x-shaped (input, output) pair and apply whatever model it
//        picked through ctx.session.switchModel before the turn runs.
//
// The upstream "event" hook (per-tier fallbacks) is deliberately not wired:
// this config leaves tier fallbacks unset and model-fallback owns recovery.
import { createAutoRouterWithConfig } from "opencode-auto-router";
// Not re-exported from the package entry; a relative path bypasses its
// `exports` map. node_modules/opencode-auto-router is the pinned npm tarball.
import { normalizeConfig } from "./node_modules/opencode-auto-router/dist/config.js";

const sameRef = (a, b) =>
  !!a && !!b && a.providerID === b.providerID && a.modelID === b.modelID && (a.variant ?? "") === (b.variant ?? "");

const unwrap = (r) => (r && typeof r === "object" && "data" in r ? r.data : r);

export default {
  id: "auto-router",
  setup: async (ctx) => {
    const router = await createAutoRouterWithConfig(normalizeConfig(ctx.options ?? {}));
    const chatMessage = router["chat.message"];
    if (typeof chatMessage !== "function") return;

    await ctx.session.hook("prompt", async (event) => {
      const text = event?.prompt?.text;
      if (typeof text !== "string" || !text.trim()) return;

      const session = unwrap(await ctx.session.get({ sessionID: event.sessionID }));
      // An unset session model means "use the default" (here auto-router/main).
      const ref = session?.model ?? unwrap(await ctx.model.default({}));
      if (!ref?.providerID) return;
      const current = { providerID: ref.providerID, modelID: ref.id ?? ref.modelID, variant: ref.variant };

      const input = {
        sessionID: event.sessionID,
        agent: session?.agent,
        model: { providerID: current.providerID, modelID: current.modelID },
        variant: current.variant,
      };
      const output = { message: { model: { ...current } }, parts: [{ type: "text", text }] };
      await chatMessage(input, output);

      const picked = output.message.model;
      if (!picked?.providerID || sameRef(picked, current)) return;
      await ctx.session.switchModel({
        sessionID: event.sessionID,
        model: {
          providerID: picked.providerID,
          id: picked.modelID,
          ...(picked.variant ? { variant: picked.variant } : {}),
        },
      });
    });
  },
};
