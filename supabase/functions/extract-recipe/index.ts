
const DEEPSEEK_API_KEY = Deno.env.get("DEEPSEEK_API_KEY") ?? "";
const FIRECRAWL_API_KEY = Deno.env.get("FIRECRAWL_API_KEY") ?? "";
const DEEPSEEK_MODEL = "deepseek-v4-flash";
// This is a reasoning model: thinking tokens and the answer come out of the
// same budget. At 4096 a long page could burn the whole allowance thinking and
// return an empty completion, which surfaced as "Could not parse DeepSeek
// response as JSON". Leave generous headroom for the answer.
const MAX_OUTPUT_TOKENS = 8192;
const FIRECRAWL_URL = "https://api.firecrawl.dev/v2/scrape";

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
  // A real caption can be short and can even mention "sign up" — only call it
  // a wall when we got a login signal AND almost no actual content, or when
  // there is effectively nothing at all.
  const hasLoginSignal = loginSignals.some((s) => lower.includes(s));
  const tooShort = content.trim().length < 80;
  return (hasLoginSignal && content.trim().length < 400) || tooShort;
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

// ── JSON-LD: schema.org/Recipe — the gold standard on recipe websites ─────────
// Nearly every recipe blog embeds an exact machine-readable recipe. Parsing it
// is deterministic: exact ingredients, steps, image, nutrition. No AI needed.
function firstStr(v: unknown): string | null {
  if (typeof v === "string" && v.trim()) return v.trim();
  if (Array.isArray(v)) {
    for (const x of v) {
      const s = firstStr(x);
      if (s) return s;
    }
  }
  if (v && typeof v === "object") {
    const o = v as Record<string, unknown>;
    return firstStr(o.url) ?? firstStr(o.text) ?? firstStr(o["@id"]) ?? null;
  }
  return null;
}

function decodeEntities(s: string): string {
  return s
    .replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"').replace(/&#0?39;/g, "'").replace(/&#x27;/gi, "'")
    .replace(/&nbsp;/g, " ").replace(/&#(\d+);/g, (_, d) => String.fromCharCode(Number(d)));
}

function isoDurationToMinutes(iso: unknown): number | null {
  if (typeof iso !== "string") return null;
  const m = iso.match(/^P(?:(\d+)D)?T?(?:(\d+)H)?(?:(\d+)M)?/i);
  if (!m) return null;
  const mins = (Number(m[1] ?? 0) * 1440) + (Number(m[2] ?? 0) * 60) + Number(m[3] ?? 0);
  return mins > 0 ? mins : null;
}

/** Pull ingredient "2 cups flour" apart into amount/unit/name (best effort). */
function parseIngredientLine(line: string): { name: string; amount: number; unit: string } {
  const cleaned = decodeEntities(line).replace(/\s+/g, " ").trim();
  const fracMap: Record<string, number> = {
    "½": 0.5, "⅓": 0.333, "⅔": 0.667, "¼": 0.25, "¾": 0.75,
    "⅕": 0.2, "⅛": 0.125, "⅜": 0.375, "⅝": 0.625, "⅞": 0.875,
  };
  const m = cleaned.match(
    /^(\d+\s+\d+\/\d+|\d+\/\d+|\d+(?:[.,]\d+)?|[½⅓⅔¼¾⅕⅛⅜⅝⅞])(?:\s*[-–]\s*[\d./½⅓⅔¼¾]+)?\s*([a-zA-Z]+\.?)?\s+(.+)$/,
  );
  if (!m) return { name: cleaned, amount: 1.0, unit: "" };
  let amount = 1.0;
  const raw = m[1];
  if (fracMap[raw] !== undefined) amount = fracMap[raw];
  else if (raw.includes("/")) {
    const parts = raw.split(/\s+/);
    amount = parts.length === 2
      ? Number(parts[0]) + Number(parts[1].split("/")[0]) / Number(parts[1].split("/")[1])
      : Number(raw.split("/")[0]) / Number(raw.split("/")[1]);
  } else amount = Number(raw.replace(",", "."));
  if (!isFinite(amount) || amount <= 0) amount = 1.0;
  const knownUnits = new Set([
    "cup", "cups", "tbsp", "tablespoon", "tablespoons", "tsp", "teaspoon",
    "teaspoons", "oz", "ounce", "ounces", "lb", "lbs", "pound", "pounds",
    "g", "gram", "grams", "kg", "ml", "l", "liter", "liters", "litre",
    "clove", "cloves", "piece", "pieces", "slice", "slices", "can", "cans",
    "stick", "sticks", "pinch", "dash", "bunch", "head", "stalk", "stalks",
  ]);
  const unitRaw = (m[2] ?? "").toLowerCase().replace(/\.$/, "");
  const unit = knownUnits.has(unitRaw) ? unitRaw : "";
  let name = unit ? m[3].trim() : `${m[2] ?? ""} ${m[3]}`.trim();
  // Drop a leading metric conversion left over from "1.5 lb / 750 g chicken".
  name = name.replace(/^\/\s*[\d.]+\s*[a-zA-Z]+\s+/, "").trim();
  // Tidy doubled/empty parentheses that recipe plugins often emit.
  name = name.replace(/\(\s*,\s*/g, "(").replace(/\(\(([^)]*)\)\)/g, "($1)");
  return { name: name || cleaned, amount: Number(amount.toFixed(3)), unit };
}

function numFromNutrition(v: unknown): number | null {
  if (typeof v === "number") return v;
  if (typeof v === "string") {
    const m = v.match(/[\d.]+/);
    if (m) return Number(m[0]);
  }
  return null;
}

/** Find a schema.org Recipe object anywhere in the page's JSON-LD blocks. */
function findRecipeNode(html: string): Record<string, unknown> | null {
  const blocks = html.matchAll(
    /<script[^>]+type=["']?application\/ld\+json["']?[^>]*>([\s\S]*?)<\/script>/gi,
  );
  const isRecipeType = (t: unknown) =>
    t === "Recipe" || (Array.isArray(t) && t.includes("Recipe"));
  for (const b of blocks) {
    let parsed: unknown;
    try {
      parsed = JSON.parse(b[1].trim());
    } catch {
      continue;
    }
    const queue: unknown[] = [parsed];
    while (queue.length) {
      const node = queue.shift();
      if (Array.isArray(node)) {
        queue.push(...node);
        continue;
      }
      if (!node || typeof node !== "object") continue;
      const o = node as Record<string, unknown>;
      if (isRecipeType(o["@type"])) return o;
      if (o["@graph"]) queue.push(o["@graph"]);
      if (o.mainEntity) queue.push(o.mainEntity);
    }
  }
  return null;
}

/** Convert a schema.org Recipe node into Plateful's recipe JSON, or null. */
function recipeFromJsonLd(html: string): Record<string, unknown> | null {
  const node = findRecipeNode(html);
  if (!node) return null;

  const ingLines: string[] = Array.isArray(node.recipeIngredient)
    ? node.recipeIngredient.filter((x): x is string => typeof x === "string")
    : [];

  const steps: string[] = [];
  const walkInstructions = (v: unknown) => {
    if (typeof v === "string") {
      const t = decodeEntities(v.replace(/<[^>]+>/g, " ")).replace(/\s+/g, " ").trim();
      if (t) steps.push(t);
    } else if (Array.isArray(v)) {
      v.forEach(walkInstructions);
    } else if (v && typeof v === "object") {
      const o = v as Record<string, unknown>;
      if (o["@type"] === "HowToSection" && o.itemListElement) {
        walkInstructions(o.itemListElement);
      } else if (typeof o.text === "string") {
        walkInstructions(o.text);
      } else if (o.itemListElement) {
        walkInstructions(o.itemListElement);
      }
    }
  };
  walkInstructions(node.recipeInstructions);

  if (ingLines.length === 0 || steps.length === 0) return null;

  const nut = (node.nutrition ?? {}) as Record<string, unknown>;
  const totalMin = isoDurationToMinutes(node.totalTime) ??
    ((isoDurationToMinutes(node.cookTime) ?? 0) + (isoDurationToMinutes(node.prepTime) ?? 0) || null);

  const servingsRaw = node.recipeYield;
  let servings: number | null = null;
  const sStr = firstStr(servingsRaw);
  if (typeof servingsRaw === "number") servings = servingsRaw;
  else if (sStr) {
    const m = sStr.match(/\d+/);
    if (m) servings = Number(m[0]);
  }

  const tags: string[] = [];
  for (const key of ["recipeCategory", "recipeCuisine", "keywords"]) {
    const v = node[key];
    if (typeof v === "string") tags.push(...v.split(",").map((s) => s.trim()));
    else if (Array.isArray(v)) {
      tags.push(...v.filter((x): x is string => typeof x === "string"));
    }
  }

  return {
    no_recipe: false,
    title: decodeEntities(firstStr(node.name) ?? "Recipe"),
    description: decodeEntities(
      (firstStr(node.description) ?? "").replace(/<[^>]+>/g, " "),
    ).replace(/\s+/g, " ").trim().slice(0, 300),
    image_url: firstStr(node.image),
    ingredients: ingLines.map(parseIngredientLine),
    steps,
    nutrition: {
      calories: numFromNutrition(nut.calories) ?? 0,
      protein: numFromNutrition(nut.proteinContent) ?? 0,
      carbs: numFromNutrition(nut.carbohydrateContent) ?? 0,
      fat: numFromNutrition(nut.fatContent) ?? 0,
    },
    tags: [...new Set(tags.map(decodeEntities))].slice(0, 6),
    servings: servings ?? 4,
    cook_time_minutes: totalMin ?? 30,
    _source: "json-ld",
  };
}

/** Fetch raw HTML, rotating user agents until one gets through. */
async function fetchHtml(url: string): Promise<string> {
  const userAgents = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
    "facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)",
    "Googlebot/2.1 (+http://www.google.com/bot.html)",
  ];
  for (const ua of userAgents) {
    try {
      const r = await fetch(url, {
        headers: {
          "User-Agent": ua,
          "Accept": "text/html,application/xhtml+xml,*/*;q=0.8",
          "Accept-Language": "en-US,en;q=0.9",
        },
        redirect: "follow",
      });
      if (r.ok) return await r.text();
      await r.body?.cancel();
    } catch { /* try next UA */ }
  }
  return "";
}

// ── Instagram: og:description carries the full caption for link crawlers ─────
// Instagram serves logged-out visitors a JS shell with no caption, but it still
// renders Open Graph tags for the Facebook crawler UA, and og:description is
// the complete caption. That's where Reel recipes live.
async function scrapeInstagram(
  url: string,
): Promise<{ content: string; imageUrl: string | null }> {
  const crawlerUas = [
    "facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)",
    "Twitterbot/1.0",
    "WhatsApp/2.23.20.0",
  ];
  for (const ua of crawlerUas) {
    let html = "";
    try {
      const r = await fetch(url, {
        headers: { "User-Agent": ua, "Accept-Language": "en-US,en;q=0.9" },
        redirect: "follow",
      });
      if (!r.ok) {
        await r.body?.cancel();
        continue;
      }
      html = await r.text();
    } catch {
      continue;
    }

    const rawDesc = extractMeta(html, "og:description");
    if (!rawDesc) continue;

    // Format is: "N likes, M comments - handle on DATE: "the caption"".
    let caption = decodeEntities(rawDesc);
    const quoted = caption.match(/:\s*"([\s\S]*)"\s*$/);
    if (quoted) caption = quoted[1];
    caption = caption.replace(/\s*\n\s*/g, "\n").trim();
    if (!caption) continue;

    const img = extractMeta(html, "og:image");
    return {
      content: `Instagram caption:\n${caption}\n`,
      imageUrl: img ? decodeEntities(img) : null,
    };
  }
  return { content: "", imageUrl: null };
}

// ── WebVTT -> plain transcript ────────────────────────────────────────────────
// TikTok's auto-captions repeat each line across overlapping cues, so dedupe
// consecutive repeats while preserving spoken order.
function vttToTranscript(vtt: string): string {
  const out: string[] = [];
  let last = "";
  for (const raw of vtt.split(/\r?\n/)) {
    const line = raw.trim();
    if (!line) continue;
    if (/^WEBVTT/.test(line) || line.includes("-->")) continue;
    if (/^\d+$/.test(line)) continue; // cue number
    if (/^(NOTE|STYLE|REGION)\b/.test(line)) continue;
    const text = line.replace(/<[^>]+>/g, "").trim();
    if (!text || text === last) continue;
    out.push(text);
    last = text;
  }
  return out.join(" ").replace(/\s+/g, " ").trim();
}

/** Pull TikTok's embedded page state (the SSR JSON blob), or null. */
function tiktokPageState(html: string): Record<string, unknown> | null {
  const marker = "__UNIVERSAL_DATA_FOR_REHYDRATION__";
  const i = html.indexOf(marker);
  if (i === -1) return null;
  const start = html.indexOf(">", i) + 1;
  const end = html.indexOf("</script>", start);
  if (start <= 0 || end <= start) return null;
  try {
    return JSON.parse(html.slice(start, end));
  } catch {
    return null;
  }
}

// ── TikTok: caption + spoken transcript ───────────────────────────────────────
// Most TikTok recipes are narrated, not written: the caption is a few dozen
// characters of hashtags while the actual ingredients and method are spoken
// aloud. TikTok auto-generates an ASR subtitle track for those videos, and it
// is the real recipe. Without it, only the rare "full recipe in the caption"
// post can import successfully.
async function scrapeTikTokPage(
  url: string,
): Promise<{ content: string; imageUrl: string | null }> {
  const html = await fetchHtml(url);
  if (!html) return { content: "", imageUrl: null };

  let content = "";
  let imageUrl: string | null = null;

  const state = tiktokPageState(html);
  const item = ((state?.__DEFAULT_SCOPE__ as Record<string, unknown> | undefined)
    ?.["webapp.video-detail"] as Record<string, unknown> | undefined)
    ?.itemInfo as Record<string, unknown> | undefined;
  const struct = item?.itemStruct as Record<string, unknown> | undefined;

  const desc = typeof struct?.desc === "string"
    ? struct.desc
    : (() => {
      const m = html.match(/"desc"\s*:\s*"((?:[^"\\]|\\.)*)"/);
      return m ? unescapeJson(m[1]) : "";
    })();
  if (desc.trim()) content += `Full TikTok caption:\n${desc.trim()}\n`;

  const video = struct?.video as Record<string, unknown> | undefined;
  if (typeof video?.cover === "string") imageUrl = video.cover;

  // Collect every candidate subtitle URL, preferring English and the original
  // (non-translated) track.
  type Sub = { url: string; lang: string; original: boolean };
  const subs: Sub[] = [];
  for (const s of (video?.subtitleInfos as Record<string, unknown>[] ?? [])) {
    if (typeof s?.Url === "string") {
      subs.push({
        url: s.Url,
        lang: String(s.LanguageCodeName ?? ""),
        original: String(s.Source ?? "") === "ASR",
      });
    }
  }
  const cla = video?.claInfo as Record<string, unknown> | undefined;
  for (const c of (cla?.captionInfos as Record<string, unknown>[] ?? [])) {
    const u = typeof c?.url === "string"
      ? c.url
      : (Array.isArray(c?.urlList) ? String(c.urlList[0] ?? "") : "");
    if (u) {
      subs.push({
        url: u,
        lang: String(c.language ?? ""),
        original: c.isOriginalCaption === true,
      });
    }
  }
  const score = (s: Sub) =>
    (s.lang.toLowerCase().startsWith("en") ? 2 : 0) + (s.original ? 1 : 0);
  subs.sort((a, b) => score(b) - score(a));

  for (const s of subs.slice(0, 3)) {
    try {
      // The CDN requires a TikTok referer for subtitle assets.
      const r = await fetch(s.url, {
        headers: {
          "User-Agent":
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
          "Referer": "https://www.tiktok.com/",
        },
      });
      if (!r.ok) {
        await r.body?.cancel();
        continue;
      }
      const transcript = vttToTranscript(await r.text());
      if (transcript.length > 60) {
        content +=
          `\nSpoken narration transcribed from the video (auto-generated, so ` +
          `expect minor transcription errors):\n${transcript.slice(0, 6000)}\n`;
        break;
      }
    } catch { /* try the next track */ }
  }

  if (!imageUrl) {
    const thumb = html.match(/property="og:image" content="([^"]+)"/i);
    imageUrl = thumb ? decodeEntities(thumb[1]) : null;
  }
  return { content, imageUrl };
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
): Promise<{ content: string; imageUrl: string | null; rawHtml: string }> {
  const onlyMainContent = source === "website";

  const res = await fetch(FIRECRAWL_URL, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${FIRECRAWL_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      url,
      // rawHtml lets us re-run the exact schema.org/Recipe parse on sites that
      // block our own fetch (allrecipes, seriouseats, and friends).
      formats: ["markdown", "rawHtml"],
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

  return {
    content: content || `Content from ${url}`,
    imageUrl,
    rawHtml: typeof data.rawHtml === "string" ? data.rawHtml : "",
  };
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
- For social posts (TikTok/Instagram/YouTube), the recipe lives in the caption or
  video description. Read it very carefully and ignore hashtags, @mentions,
  follow/like calls to action, emoji dividers, and link-in-bio text.
- Social captions are terse and unpunctuated. Treat newline-separated or
  emoji-bulleted fragments like "2 cups flour", "1 tsp salt" as ingredients, and
  imperative fragments like "bake 20 min at 350" as steps, even without headings.
- IMPORTANT: when a spoken narration transcript is included, that transcript is
  usually the real recipe and the caption is just promotional text. Reconstruct
  the recipe from what the cook says they are doing, in the order they say it.
- Transcripts are speech, so quantities are spelled out and units are casual:
  convert "two tablespoons of butter" to amount 2 unit "tbsp" name "butter",
  "a cup of heavy cream" to amount 1 unit "cup", "three to four garlic cloves"
  to amount 4 unit "clove". Ignore filler ("gonna", "okay so"), greetings, and
  engagement bait ("follow for more").
- Transcripts are auto-generated and contain homophone errors. Correct obvious
  food-word mistakes from context (for example "then a mint" -> "then add mint",
  "oil of oil" -> "olive oil") rather than treating them as real ingredients.
- If a quantity is genuinely never stated, use a sensible standard amount for
  that ingredient rather than dropping the ingredient.
- If the caption clearly names a dish and lists its ingredients but the method
  was only shown on video, write the standard cooking steps that those
  ingredients imply. Keep them short and conventional; do not add ingredients
  that were never mentioned.
- Only use no_recipe:true when there is genuinely no food content: a login wall,
  an unrelated topic, or a caption with no dish and no ingredients. A recipe that
  is merely terse or incomplete is still a recipe.
- Estimate nutrition if not stated
- Return ONLY the JSON object`;

  // First pass with the full scraped content.
  let out = await callDeepSeek(prompt, MAX_OUTPUT_TOKENS);
  let parsed = parseJsonLoose(out.text) ?? parseJsonLoose(out.reasoning);

  // The model reasons and answers out of the same token budget. On a long or
  // messy page it can spend the entire allowance thinking and return nothing
  // at all (finish_reason "length", empty content). Retry once on a trimmed
  // prompt so there is less to deliberate over and room left to answer.
  if (!parsed && (out.truncated || !out.text.trim())) {
    console.log(JSON.stringify({
      fn: "extract-recipe",
      warn: "empty or truncated completion, retrying on trimmed input",
      finishReason: out.finishReason,
      reasoningTokens: out.reasoningTokens,
    }));
    const trimmed = prompt.length > 4000
      ? `${prompt.slice(0, 2600)}\n\n[content trimmed]\n\n${prompt.slice(-1400)}`
      : prompt;
    out = await callDeepSeek(
      `${trimmed}\n\nAnswer immediately with the JSON object. Do not deliberate.`,
      MAX_OUTPUT_TOKENS,
    );
    parsed = parseJsonLoose(out.text) ?? parseJsonLoose(out.reasoning);
  }

  if (parsed) return parsed;

  if (out.truncated || !out.text.trim()) {
    throw new Error(
      "The recipe model ran out of room before answering " +
        `(finish_reason=${out.finishReason}, reasoning_tokens=${out.reasoningTokens})`,
    );
  }
  throw new Error("Could not parse DeepSeek response as JSON");
}

interface DeepSeekOut {
  text: string;
  reasoning: string;
  finishReason: string;
  truncated: boolean;
  reasoningTokens: number;
}

/** One DeepSeek call, returning content plus the signals we need to recover. */
async function callDeepSeek(
  prompt: string,
  maxTokens: number,
): Promise<DeepSeekOut> {
  const response = await fetch("https://api.deepseek.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${DEEPSEEK_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: DEEPSEEK_MODEL,
      max_tokens: maxTokens,
      temperature: 0.2,
      // JSON mode: guarantees the reply is a single valid JSON object.
      response_format: { type: "json_object" },
      messages: [{ role: "user", content: prompt }],
    }),
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(
      `DeepSeek API error: ${response.status} ${body.slice(0, 200)}`,
    );
  }

  const data = await response.json();
  const { usage, costUsd } = deepseekCost(data.usage);
  const choice = data.choices?.[0] ?? {};
  const msg = choice.message ?? {};
  const finishReason = String(choice.finish_reason ?? "");
  const reasoningTokens =
    data.usage?.completion_tokens_details?.reasoning_tokens ?? 0;

  // Cost analytics: console only (visible in the Deno Deploy logs).
  // Intentionally NOT returned to the client / UI.
  console.log(JSON.stringify({
    fn: "extract-recipe",
    model: DEEPSEEK_MODEL,
    usage,
    costUsd,
    finishReason,
  }));

  return {
    text: typeof msg.content === "string" ? msg.content : "",
    // Reasoning models expose their scratchpad separately. If the answer got
    // cut off mid-flight the JSON is sometimes recoverable from here.
    reasoning: typeof msg.reasoning_content === "string"
      ? msg.reasoning_content
      : "",
    finishReason,
    truncated: finishReason === "length",
    reasoningTokens,
  };
}

/** Parse a JSON object out of raw text, tolerating fences and prose. */
function parseJsonLoose(text: string): Record<string, unknown> | null {
  if (!text || !text.trim()) return null;
  try {
    const v = JSON.parse(text);
    if (v && typeof v === "object") return v as Record<string, unknown>;
  } catch { /* fall through */ }
  const fence = text.match(/```(?:json)?\s*([\s\S]*?)```/);
  if (fence) {
    try {
      const v = JSON.parse(fence[1]);
      if (v && typeof v === "object") return v as Record<string, unknown>;
    } catch { /* fall through */ }
  }
  const start = text.indexOf("{");
  const end = text.lastIndexOf("}");
  if (start !== -1 && end > start) {
    try {
      const v = JSON.parse(text.slice(start, end + 1));
      if (v && typeof v === "object") return v as Record<string, unknown>;
    } catch { /* fall through */ }
  }
  return null;
}

// ── Main handler ──────────────────────────────────────────────────────────────
// ── Per-IP rate limiting (in-memory, per isolate) ─────────────────────
const RATE_LIMIT_MAX = 8;
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

// ── YouTube: normalize Shorts/short-links and pull the video description ───────
function normalizeYouTubeUrl(url: string): string {
  const shorts = url.match(/youtube\.com\/shorts\/([A-Za-z0-9_-]{6,})/);
  if (shorts) return `https://www.youtube.com/watch?v=${shorts[1]}`;
  const be = url.match(/youtu\.be\/([A-Za-z0-9_-]{6,})/);
  if (be) return `https://www.youtube.com/watch?v=${be[1]}`;
  return url;
}

function unescapeJson(s: string): string {
  try {
    return JSON.parse(`"${s}"`);
  } catch {
    return s.replace(/\\n/g, "\n").replace(/\\"/g, '"').replace(/\\u0026/g, "&");
  }
}

// Shorts pages return empty on a direct fetch, but the /watch page carries the
// full description in ytInitialData ("shortDescription") — that's the recipe.
async function scrapeYouTube(
  url: string,
): Promise<{ content: string; imageUrl: string | null }> {
  const watch = normalizeYouTubeUrl(url);
  const res = await fetch(watch, {
    headers: {
      "User-Agent":
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      "Accept-Language": "en-US,en;q=0.9",
    },
  });
  if (!res.ok) return { content: "", imageUrl: null };
  const html = await res.text();
  const descMatch = html.match(/"shortDescription":"((?:[^"\\]|\\.)*)"/);
  const content = descMatch
    ? `Video description:\n${unescapeJson(descMatch[1])}\n`
    : "";
  const thumb = html.match(/<meta property="og:image" content="([^"]+)"/);
  return { content, imageUrl: thumb ? thumb[1] : null };
}

// ── Caption-link fallback ─────────────────────────────────────────────────────
// Creators often caption "full recipe on my blog ⬇️" with a link instead of
// pasting the recipe. When a social post's caption/description contains an
// external link, scrape that page too — the canonical recipe usually lives there.
const CAPTION_LINK_SKIP = [
  "tiktok.com", "instagram.com", "youtube.com", "youtu.be", "facebook.com",
  "fb.watch", "twitter.com", "x.com", "linktr.ee", "beacons.ai", "bio.link",
  "lnk.bio", "linkin.bio", "amazon.", "amzn.to", "discord.gg", "patreon.com",
  "spotify.com", "apple.com", "google.com/store", "play.google.com",
];

function findCaptionLink(text: string, originalUrl: string): string | null {
  const matches = text.match(/https?:\/\/[^\s"'<>()\[\]]+/g) ?? [];
  for (let m of matches) {
    m = m.replace(/[.,;:!?]+$/, ""); // strip trailing punctuation
    let host: string;
    try {
      host = new URL(m).hostname.toLowerCase();
    } catch {
      continue;
    }
    if (m === originalUrl) continue;
    if (CAPTION_LINK_SKIP.some((s) => host.includes(s) || m.includes(s))) {
      continue;
    }
    return m;
  }
  return null;
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

    // Websites: try schema.org/Recipe JSON-LD first. It's exact and instant —
    // no AI, no scraping service, no parse failures.
    if (source === "website") {
      const html = await fetchHtml(url);
      if (html) {
        const ld = recipeFromJsonLd(html);
        if (ld) {
          console.log(JSON.stringify({ fn: "extract-recipe", path: "json-ld", url }));
          return new Response(JSON.stringify(ld), {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          });
        }
        // No JSON-LD; reuse this HTML as AI context instead of re-fetching.
        const title = extractMeta(html, "og:title") ?? "";
        const description = extractMeta(html, "og:description") ?? "";
        imageUrl = extractMeta(html, "og:image");
        if (title) content += `Title: ${title}\n`;
        if (description) content += `Description: ${description}\n`;
        content += `\nPage content:\n${stripHtml(html)}`;
      }
    }

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
    // TikTok's oEmbed title truncates long captions — the page JSON has the
    // full "desc", which is where detailed recipes live.
    if (source === "tiktok") {
      try {
        const t = await scrapeTikTokPage(url);
        if (t.content) content += `\n${t.content}`;
        imageUrl = imageUrl ?? t.imageUrl;
      } catch (e) {
        console.error("TikTok page scrape failed:", e);
      }
    }
    // Instagram blocks anonymous page loads, but its /embed/captioned endpoint
    // serves the caption without login.
    if (source === "instagram") {
      try {
        const ig = await scrapeInstagram(url);
        if (ig.content) content += `\n${ig.content}`;
        imageUrl = imageUrl ?? ig.imageUrl;
      } catch (e) {
        console.error("Instagram embed scrape failed:", e);
      }
    }
    if (source === "youtube") {
      try {
        const yt = await scrapeYouTube(url);
        if (yt.content) content += `\n${yt.content}`;
        imageUrl = imageUrl ?? yt.imageUrl;
      } catch (e) {
        console.error("YouTube scrape failed:", e);
      }
    }

    // Firecrawl: rendered page content — only when direct scraping came up
    // short (saves credits and ~5s when the caption already has the recipe).
    if (FIRECRAWL_API_KEY && content.trim().length < 250) {
      try {
        const r = await scrapeWithFirecrawl(url, source);
        // Firecrawl got past the block: retry the exact JSON-LD parse.
        if (r.rawHtml) {
          const ld = recipeFromJsonLd(r.rawHtml);
          if (ld) {
            if (!ld.image_url && (imageUrl ?? r.imageUrl)) {
              ld.image_url = imageUrl ?? r.imageUrl;
            }
            console.log(JSON.stringify({
              fn: "extract-recipe", path: "json-ld-firecrawl", url,
            }));
            return new Response(JSON.stringify(ld), {
              headers: { ...corsHeaders, "Content-Type": "application/json" },
            });
          }
        }
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

    // Caption-link fallback: if the caption points at an external site (the
    // creator's blog), scrape that page too — it usually holds the full recipe.
    if (source !== "website") {
      const linked = findCaptionLink(content, url);
      if (linked) {
        try {
          // The linked blog usually has JSON-LD — exact recipe, done.
          let html = await fetchHtml(linked);
          // Blocked? Let Firecrawl fetch it so JSON-LD is still reachable.
          if (!html && FIRECRAWL_API_KEY) {
            try {
              html = (await scrapeWithFirecrawl(linked, "website")).rawHtml;
            } catch { /* fall through to the AI path */ }
          }
          const ld = html ? recipeFromJsonLd(html) : null;
          if (ld) {
            if (imageUrl && !ld.image_url) ld.image_url = imageUrl;
            console.log(JSON.stringify({
              fn: "extract-recipe", path: "json-ld-linked", url, linked,
            }));
            return new Response(JSON.stringify(ld), {
              headers: { ...corsHeaders, "Content-Type": "application/json" },
            });
          }
          const r = html
            ? { content: stripHtml(html), imageUrl: extractMeta(html, "og:image") }
            : (FIRECRAWL_API_KEY
              ? await scrapeWithFirecrawl(linked, "website")
              : await scrapeDirect(linked));
          if (r.content) content += `\nLinked page (${linked}):\n${r.content}`;
          imageUrl = imageUrl ?? r.imageUrl;
        } catch (e) {
          console.error("Caption-link scrape failed:", e);
        }
      }
    }

    const blocked = isLoginWall(content, source);
    // Diagnostic: how much real content the scrape produced, per source.
    console.log(JSON.stringify({
      fn: "extract-recipe", path: "ai", source, url,
      contentChars: content.trim().length, hasImage: !!imageUrl, blocked,
    }));
    const recipe = await extractWithDeepSeek(content, source, imageUrl);

    // The model is told the image URL but frequently drops or nulls it —
    // especially for videos, where the thumbnail is the only image. The scraped
    // value is ground truth, so it wins over whatever came back.
    const modelImage = typeof recipe.image_url === "string"
      ? recipe.image_url.trim()
      : "";
    if (imageUrl) {
      recipe.image_url = imageUrl;
    } else if (!modelImage.startsWith("http")) {
      recipe.image_url = null;
    }

    // Guard against hallucination / empty imports: a real recipe needs BOTH
    // ingredients and steps. Otherwise return a clear no_recipe signal.
    const ingredients = Array.isArray(recipe.ingredients) ? recipe.ingredients : [];
    const steps = Array.isArray(recipe.steps) ? recipe.steps : [];
    const tooThin = ingredients.length === 0 || steps.length === 0;

    // If the model produced a full recipe, trust it even when the page also
    // showed login prompts — captions often coexist with sign-up banners.
    if (recipe.no_recipe === true || tooThin) {
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
