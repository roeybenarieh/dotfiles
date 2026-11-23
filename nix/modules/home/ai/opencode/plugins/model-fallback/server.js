// OpenCode 2 model fallback. Replaces @smart-coders-hq/opencode-model-fallback,
// which only ships a 1.x plugin and is unmaintained. Keeps that plugin's
// config shape (passed as this plugin's `options` in opencode.json) and its
// error classifier, re-implemented on the 2.x `retry` hook:
//
//   - When a request fails with a category listed in `fallbackOn`, switch the
//     session to the next healthy model in its chain and retry immediately.
//     The chain is [the model the session failed on, ...fallbackModels].
//   - rate_limit / quota_exceeded mark the model unhealthy for `cooldownMs`,
//     so later failures skip it (in memory only, reset on restart).
//   - `retryOriginalAfterMs` after a fallback, the next prompt in that session
//     switches back to the original model if it is healthy again.
//   - At most `maxFallbackDepth` fallbacks per original model per session.
//
// Options: { enabled, defaults: { fallbackOn, cooldownMs, retryOriginalAfterMs,
// maxFallbackDepth }, agents: { "<agent>"|"*": { fallbackModels: ["p/m", ...] } },
// logging }.

const RATE_LIMIT = ["rate limit", "ratelimit", "too many requests", "usage limit", "resource exhausted", "resource_exhausted", "429"];
const QUOTA = ["quota exceeded", "credits exhausted", "billing limit", "credit limit", "insufficient quota", "insufficient credit", "insufficient credits", "out of credits"];
const OVERLOADED = ["overloaded", "capacity exceeded", "server is busy", "engine is currently overloaded"];
const TIMEOUT = ["timeout", "timed out", "request timeout", "connection timeout"];
const SERVER = ["internal server error", "bad gateway", "service unavailable", "gateway timeout", "500", "502", "503", "504"];

const any = (text, patterns) => patterns.some((p) => text.includes(p));

// Same precedence as the upstream classifier (src/detection/classifier.ts).
export function classifyError(message, status) {
  const text = String(message ?? "").toLowerCase();
  if (status === 429 || any(text, RATE_LIMIT)) return "rate_limit";
  if (status === 402 || any(text, QUOTA)) return "quota_exceeded";
  if (status === 529 || any(text, OVERLOADED)) return "overloaded";
  if (any(text, TIMEOUT)) return "timeout";
  if ((status !== undefined && status >= 500) || any(text, SERVER)) return "5xx";
  return "unknown";
}

const key = (ref) => `${ref.providerID}/${ref.id}`;
const parse = (s) => {
  const i = s.indexOf("/");
  return { providerID: s.slice(0, i), id: s.slice(i + 1) };
};
const unwrap = (r) => (r && typeof r === "object" && "data" in r ? r.data : r);

export default {
  id: "model-fallback",
  setup: async (ctx) => {
    const opts = ctx.options ?? {};
    if (opts.enabled === false) return;
    const d = opts.defaults ?? {};
    const fallbackOn = new Set(d.fallbackOn ?? ["rate_limit", "quota_exceeded", "5xx", "timeout", "overloaded"]);
    const cooldownMs = d.cooldownMs ?? 300000;
    const retryOriginalAfterMs = d.retryOriginalAfterMs ?? cooldownMs;
    const maxDepth = d.maxFallbackDepth ?? 3;
    const agents = opts.agents ?? {};
    const log = (msg, extra) => {
      if (opts.logging !== false) console.log(`[model-fallback] ${msg}`, extra ? JSON.stringify(extra) : "");
    };

    const unhealthyUntil = new Map(); // model key -> epoch ms
    const sessions = new Map(); // sessionID -> { original, depth, since }
    const healthy = (ref, now) => (unhealthyUntil.get(key(ref)) ?? 0) <= now;

    const chainFor = (agent) =>
      ((agents[agent] ?? agents["*"] ?? {}).fallbackModels ?? []).map(parse);

    await ctx.session.hook("retry", async (event) => {
      const category = classifyError(event.error?.message, event.error?.status);
      if (!fallbackOn.has(category)) return;
      const now = Date.now();
      const failed = { providerID: event.model.providerID, id: event.model.id };
      if (category === "rate_limit" || category === "quota_exceeded") {
        unhealthyUntil.set(key(failed), now + cooldownMs);
      }

      const state = sessions.get(event.sessionID) ?? { original: event.model, depth: 0 };
      if (state.depth >= maxDepth) return log("max depth reached", { sessionID: event.sessionID });
      const chain = [failed, ...chainFor(event.agent)];
      const start = chain.findIndex((m) => key(m) === key(failed));
      const next = chain.slice(start + 1).find((m) => key(m) !== key(failed) && healthy(m, now));
      if (!next) return log("no healthy fallback", { from: key(failed), category });

      await ctx.session.switchModel({ sessionID: event.sessionID, model: next });
      sessions.set(event.sessionID, { original: state.original, depth: state.depth + 1, since: now });
      event.decision = { retry: true, delay: 0 };
      log("fallback", { sessionID: event.sessionID, from: key(failed), to: key(next), category });
    });

    // Return to the original model once it has had time to recover.
    await ctx.session.hook("prompt", async (event) => {
      const state = sessions.get(event.sessionID);
      if (!state) return;
      const now = Date.now();
      if (now - state.since < retryOriginalAfterMs || !healthy(state.original, now)) return;
      const session = unwrap(await ctx.session.get({ sessionID: event.sessionID }));
      sessions.delete(event.sessionID);
      if (session?.model && key(session.model) === key(state.original)) return;
      await ctx.session.switchModel({ sessionID: event.sessionID, model: state.original });
      log("restored original", { sessionID: event.sessionID, to: key(state.original) });
    });
  },
};
