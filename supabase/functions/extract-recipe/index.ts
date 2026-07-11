
const DEEPSEEK_API_KEY = Deno.env.get("DEEPSEEK_API_KEY") ?? "";
const FIRECRAWL_API_KEY = Deno.env.get("FIRECRAWL_API_KEY") ?? "";
const DEEPSEEK_MODEL = "deepseek-chat"; // DeepSeek V3 Pro (aka deepseek-chat)
const FIRECRAWL_URL = "https://api.firecrawl.dev/v2/scrape";

// DeepSeek deepseek-chat pricing, USD per 1M tokens.
// VERIFY/UPDATE at https://api-docs.deepseek.com (rates change; off-peak is cheaper).
const PRICE_INPUT_CACHE_HIT = 0.07;
const PRICE_INPUT_CACHE_MISS = 0.27;
const PRICE_OUTPUT = 1.10;

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
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function detectSource(url: string): "tiktok" | "instagram" | "youtube" | "website" {
  if (url.includes("tiktok.com")) return "tiktok";
  if (url.includes("instagram.com")) return "instagram";
  if (url.includes("youtube.com") || url.includes("youtu.be")) return "youtube";
  return "website";
}

/** Returns true if the scraped content looks like a login wall / empty social page. */
function isLoginWall(content: string, source: string): boolean {
  if (source !== "tiktok" && source !== "instagram") return false;
  const lower = content.toLowerCase();
  const loginSignals = [
    "log in", "login", "sign in", "sign up", "create account",
    "you must be logged", "join tiktok", "join instagram",
    "this content isn't available", "this page isn't available",
  ];
  const hasLoginSignal = loginSignals.some((s) => lower.includes(s));
  // If the content is very short AND has a login signal, it's a wall
  const tooShort = content.length < 400;
  return hasLoginSignal || tooShort;
}

function extractMeta(html: string, property: string): string | null {
  const re1 = new RegExp(
    `<meta[^>]+(?:property|name)=["']${property}["'][^>]+content=["']([^"']+)["']`,
    "i",
  );
  const re2 = new RegExp(
    `<meta[^>]+content=["']([^"']+)["'][^>]+(?:property|name)=["']${property}["']`,
    "i",
  );
  return re1.exec(html)?.[1] ?? re2.exec(html)?.[1] ?? null;
}

function stripHtml(html: string): string {
  return html
    .replace(/<script[\s\S]*?<\/script>/gi, "")
    .replace(/<style[\s\S]*?<\/style>/gi, "")
    .replace(/<[^>]+>/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 10000);
}

// ── oEmbed: gets the real caption/title for TikTok & YouTube without login ─────
async function scrapeOEmbed(
  url: string,
  source: string,
): Promise<{ content: string; imageUrl: string | null }> {
  let endpoint: string | null = null;
  if (source === "tiktok") {
    endpoint = `https://www.tiktok.com/oembed?url=${encodeURIComponent(url)}`;
  } else if (source === "youtube") {
    endpoint = `https://www.youtube.com/oembed?url=${encodeURIComponent(url)}&format=json`;
  }
  if (!endpoint) return { content: "", imageUrl: null };

  const res = await fetch(endpoint, {
    headers: { "User-Agent": "Mozilla/5.0 (compatible; PlatefulBot/1.0)" },
  });
  if (!res.ok) return { content: "", imageUrl: null };

  const j = await res.json();
  const title: string = j.title ?? "";
  const author: string = j.author_name ?? "";
  const imageUrl: string | null = j.thumbnail_url ?? null;

  // TikTok's oembed `title` is the full caption — often the whole recipe.
  let content = "";
  if (title) content += `Caption/Title: ${title}\n`;
  if (author) content += `Author: ${author}\n`;
  return { content, imageUrl };
}

// ── Primary: Firecrawl scrape (handles JS / social pages) ─────────────────────
async function scrapeWithFirecrawl(
  url: string,
  source: string,
): Promise<{ content: string; imageUrl: string | null }> {
  const onlyMainContent = source === "website";

  const res = await fetch(FIRECRAWL_URL, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${FIRECRAWL_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      url,
      formats: ["markdown"],
      onlyMainContent,
      waitFor: source === "website" ? 0 : 2500,
      timeout: 45000,
    }),
  });

  if (!res.ok) {
    const body = await res.text();
    throw new Error(`Firecrawl ${res.status}: ${body.slice(0, 160)}`);
  }

  const json = await res.json();
  const data = json.data ?? json;
  const meta = data.metadata ?? {};

  const markdown: string = data.markdown ?? "";
  const title: string = meta.title ?? meta.ogTitle ?? "";
  const description: string = meta.description ?? meta.ogDescription ?? "";

  let imageUrl: string | null = meta.ogImage ?? meta.image ?? null;
  if (Array.isArray(imageUrl)) imageUrl = imageUrl[0] ?? null;

  let content = "";
  if (title) content += `Title: ${title}\n`;
  if (description) content += `Description: ${description}\n`;
  if (markdown) content += `\nPage content:\n${markdown.slice(0, 12000)}`;

  return { content: content || `Content from ${url}`, imageUrl };
}

// ── Fallback: direct fetch (no Firecrawl credits needed) ──────────────────────
async function scrapeDirect(
  url: string,
): Promise<{ content: string; imageUrl: string | null }> {
  const userAgents = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
    "facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)",
    "Googlebot/2.1 (+http://www.google.com/bot.html)",
  ];

  let html = "";
  for (const ua of userAgents) {
    try {
      const r = await fetch(url, {
        headers: {
          "User-Agent": ua,
          "Accept": "text/html,application/xhtml+xml,*/*;q=0.8",
          "Accept-Language": "en-US,en;q=0.9",
        },
      });
      if (r.ok) {
        html = await r.text();
        break;
      }
    } catch { /* try next UA */ }
  }

  if (!html) {
    return { content: `Recipe URL (page could not be fetched): ${url}`, imageUrl: null };
  }

  const title = extractMeta(html, "og:title") ?? extractMeta(html, "title") ?? "";
  const description =
    extractMeta(html, "og:description") ?? extractMeta(html, "description") ?? "";
  const imageUrl = extractMeta(html, "og:image");

  let content = "";
  if (title) content += `Title: ${title}\n`;
  if (description) content += `Description: ${description}\n`;
  content += `\nPage content:\n${stripHtml(html)}`;

  return { content, imageUrl };
}

// ── DeepSeek extraction ───────────────────────────────────────────────────────
async function extractWithDeepSeek(
  content: string,
  sourceType: string,
  imageUrl: string | null,
): Promise<Record<string, unknown>> {
  const prompt = `You are a recipe extraction expert. Extract the recipe from this ${sourceType} content.

${content}

Return ONLY valid JSON. Use this structure when a recipe IS present:
{
  "no_recipe": false,
  "title": "Recipe name",
  "description": "Brief 1-2 sentence description",
  "image_url": ${imageUrl ? `"${imageUrl}"` : "null"},
  "ingredients": [{"name": "ingredient name", "amount": 1.0, "unit": "cup"}],
  "steps": ["Step 1 instruction", "Step 2 instruction"],
  "nutrition": {"calories": 350, "protein": 20.0, "carbs": 40.0, "fat": 15.0},
  "tags": ["tag1", "tag2"],
  "servings": 4,
  "cook_time_minutes": 30
}

If you CANNOT find any real recipe content (e.g. the page is a login wall, the content is
about something completely unrelated to food, or there are zero ingredients/steps to extract),
return this instead:
{
  "no_recipe": true,
  "reason": "One sentence explaining why (e.g. Instagram required login, no recipe in caption)"
}

Rules:
- amount must be numeric (e.g. 1.0, 0.5, 2.0); use 1.0 if unknown
- unit: standard units (cup, tbsp, tsp, oz, g, ml, clove, piece) or "" if none
- Extract ALL ingredients and ALL steps you can find
- For social posts (TikTok/Instagram/YouTube), the recipe is usually in the caption/description — read it carefully
- Do NOT invent a recipe if there is no real content to extract; use no_recipe:true instead
- Estimate nutrition if not stated
- Return ONLY the JSON object`;

  // DeepSeek uses an OpenAI-compatible API
  const response = await fetch("https://api.deepseek.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${DEEPSEEK_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: DEEPSEEK_MODEL,
      max_tokens: 4096,
      messages: [{ role: "user", content: prompt }],
    }),
  });

  if (!response.ok) {
    throw new Error(`DeepSeek API error: ${response.status}`);
  }

  const data = await response.json();
  const { usage, costUsd } = deepseekCost(data.usage);
  // Cost analytics: console only (visible in `supabase functions logs extract-recipe`).
  // Intentionally NOT returned to the client / UI.
  console.log(JSON.stringify({ fn: "extract-recipe", model: DEEPSEEK_MODEL, usage, costUsd }));
  // OpenAI-compatible response: choices[0].message.content
  const text = data.choices[0].message.content as string;
  const jsonMatch = text.match(/{[\s\S]*}/);
  if (jsonMatch) {
    try {
      return JSON.parse(jsonMatch[0]);
    } catch { /* fall through */ }
  }
  throw new Error("Could not parse DeepSeek response as JSON");
}

// ── Main handler ──────────────────────────────────────────────────────────────
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const APP_SECRET = Deno.env.get("PLATEFUL_APP_SECRET") ?? "";
  if (APP_SECRET && req.headers.get("x-plateful-key") !== APP_SECRET) {
    return new Response(JSON.stringify({ error: "unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    const { url } = await req.json();
    if (!url) {
      return new Response(JSON.stringify({ error: "url is required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const source = detectSource(url);

    let content = "";
    let imageUrl: string | null = null;

    // oEmbed first for TikTok/YouTube — returns the real caption (the recipe)
    // without needing a login. This is the key source for social recipes.
    if (source === "tiktok" || source === "youtube") {
      try {
        const r = await scrapeOEmbed(url, source);
        content = r.content;
        imageUrl = r.imageUrl;
      } catch (e) {
        console.error("oEmbed failed:", e);
      }
    }

    // Firecrawl: rendered page content (and Instagram caption).
    if (FIRECRAWL_API_KEY) {
      try {
        const r = await scrapeWithFirecrawl(url, source);
        if (r.content) content += `\n${r.content}`;
        imageUrl = imageUrl ?? r.imageUrl;
      } catch (e) {
        console.error("Firecrawl failed, falling back to direct fetch:", e);
      }
    }

    // Direct fetch fallback if we still have almost nothing.
    if (!content || content.trim().length < 40) {
      try {
        const r = await scrapeDirect(url);
        content += `\n${r.content}`;
        imageUrl = imageUrl ?? r.imageUrl;
      } catch (e) {
        console.error("Direct fetch failed:", e);
      }
    }

    const blocked = isLoginWall(content, source);
    const recipe = await extractWithDeepSeek(content, source, imageUrl);

    // Guard against hallucination / empty imports: a real recipe needs BOTH
    // ingredients and steps. Otherwise return a clear no_recipe signal.
    const ingredients = Array.isArray(recipe.ingredients) ? recipe.ingredients : [];
    const steps = Array.isArray(recipe.steps) ? recipe.steps : [];
    const tooThin = ingredients.length === 0 || steps.length === 0;

    if (recipe.no_recipe === true || blocked || tooThin) {
      return new Response(
        JSON.stringify({
          no_recipe: true,
          reason: (recipe.reason as string | undefined) ||
            (blocked
              ? "This post needs a login to view, so the recipe couldn't be read. Open it and paste the caption into Manual entry."
              : "No full recipe (ingredients + steps) was found at this link. Try a post that lists them, or add it manually."),
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    return new Response(JSON.stringify(recipe), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("extract-recipe error:", err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
