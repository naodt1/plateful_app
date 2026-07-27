
// Server-side DeepSeek proxy. Keeps the API key off the client.
const DEEPSEEK_API_KEY = Deno.env.get("DEEPSEEK_API_KEY") ?? "";
const DEEPSEEK_URL = "https://api.deepseek.com/v1/chat/completions";
const MODEL = "deepseek-v4-flash";

// DeepSeek deepseek-v4-flash pricing, USD per 1M tokens.
// VERIFY/UPDATE at https://api-docs.deepseek.com (rates change; off-peak is cheaper).
const PRICE_INPUT_CACHE_HIT = 0.0028;
const PRICE_INPUT_CACHE_MISS = 0.14;
const PRICE_OUTPUT = 0.28;

/** Compute USD cost from a DeepSeek/OpenAI-style usage object. */
function deepseekCost(usage: Record<string, number> | undefined) {
  const u = usage ?? {};
  const hit = u.prompt_cache_hit_tokens ?? 0;
  const miss = u.prompt_cache_miss_tokens ?? Math.max((u.prompt_tokens ?? 0) - hit, 0);
  const out = u.completion_tokens ?? 0;
  const costUsd =
    (hit / 1e6) * PRICE_INPUT_CACHE_HIT +
    (miss / 1e6) * PRICE_INPUT_CACHE_MISS +
    (out / 1e6) * PRICE_OUTPUT;
  return { usage: u, costUsd: Number(costUsd.toFixed(6)) };
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// ── Per-IP rate limiting (in-memory, per isolate) ─────────────────────
const RATE_LIMIT_MAX = 15;
const RATE_LIMIT_WINDOW_MS = 60_000;
const _rlHits = new Map<string, { count: number; reset: number }>();
function clientIp(req: Request): string {
  const xff = req.headers.get("x-forwarded-for");
  if (xff) return xff.split(",")[0].trim();
  return req.headers.get("x-real-ip") ?? "unknown";
}
function isRateLimited(ip: string): boolean {
  const now = Date.now();
  if (_rlHits.size > 5000) {
    for (const [k, v] of _rlHits) if (now > v.reset) _rlHits.delete(k);
  }
  const e = _rlHits.get(ip);
  if (!e || now > e.reset) {
    _rlHits.set(ip, { count: 1, reset: now + RATE_LIMIT_WINDOW_MS });
    return false;
  }
  e.count++;
  return e.count > RATE_LIMIT_MAX;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const _ip = clientIp(req);
  if (isRateLimited(_ip)) {
    return new Response(JSON.stringify({ error: "rate limited, slow down" }), {
      status: 429,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const APP_SECRET = Deno.env.get("PLATEFUL_APP_SECRET") ?? "";
  if (APP_SECRET && req.headers.get("x-plateful-key") !== APP_SECRET) {
    return new Response(JSON.stringify({ error: "unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    const { prompt } = await req.json();
    if (!prompt || typeof prompt !== "string") {
      return new Response(JSON.stringify({ error: "prompt is required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (!DEEPSEEK_API_KEY) {
      return new Response(
        JSON.stringify({ error: "AI not configured on server" }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const res = await fetch(DEEPSEEK_URL, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${DEEPSEEK_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: 4096,
        messages: [{ role: "user", content: prompt }],
      }),
    });

    if (!res.ok) {
      const body = await res.text();
      return new Response(
        JSON.stringify({ error: `AI error ${res.status}`, detail: body.slice(0, 300) }),
        {
          status: res.status,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const json = await res.json();
    const content = json.choices?.[0]?.message?.content ?? "";
    const { usage, costUsd } = deepseekCost(json.usage);
    // Cost analytics: console only (visible in `supabase functions logs ai-chat`).
    // Intentionally NOT returned to the client / UI.
    console.log(JSON.stringify({ fn: "ai-chat", model: MODEL, usage, costUsd }));
    return new Response(JSON.stringify({ content }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
