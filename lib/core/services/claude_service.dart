import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thrown when a URL is shared from a platform (Instagram, TikTok, etc.) that
/// blocks scraping and no recipe content could be retrieved.
class NoRecipeFoundException implements Exception {
  final String reason;
  const NoRecipeFoundException(this.reason);

  @override
  String toString() => reason;
}

class ClaudeService {
  /// Deno Deploy function for server-side URL fetching + recipe extraction.
  static const String _extractFunctionUrl =
      'https://plateful-extract-recipe.naodt1.deno.net';

  /// Deno Deploy function that proxies AI chat (keeps the AI key server-side).
  static const String _aiChatUrl = 'https://plateful-ai-chat.naodt1.deno.net';

  /// Shared secret sent with every request so the public Deno endpoints reject
  /// calls that don't come from the app. Lives in .env (gitignored), not source.
  static String get _appSecret => dotenv.env['PLATEFUL_APP_SECRET'] ?? '';

  /// Runs an AI prompt through the server-side proxy. The AI provider key
  /// lives only in the edge function, never in the shipped app.
  static Future<String> _chat(String prompt) async {
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await http
            .post(
              Uri.parse(_aiChatUrl),
              headers: {'Content-Type': 'application/json', 'x-plateful-key': _appSecret},
              body: jsonEncode({'prompt': prompt}),
            )
            .timeout(const Duration(seconds: 60));

        if (response.statusCode == 429) {
          throw Exception('Too many requests right now. Please try again shortly.');
        }
        if (response.statusCode != 200) {
          throw Exception('Recipe service error (${response.statusCode}).');
        }

        final json = jsonDecode(response.body) as Map<String, dynamic>;
        if (json['error'] != null) {
          throw Exception(json['error'].toString());
        }
        return json['content'] as String? ?? '';
      } on Exception {
        if (attempt == 1) rethrow;
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    throw Exception('Unexpected error contacting the recipe service.');
  }

  static Map<String, dynamic>? _extractJson(String text) {
    try {
      // Try direct parse
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {}

    // Extract from code block
    final codeBlockRegex = RegExp(r'```(?:json)?\s*([\s\S]*?)```');
    final match = codeBlockRegex.firstMatch(text);
    if (match != null) {
      try {
        return jsonDecode(match.group(1)!) as Map<String, dynamic>;
      } catch (_) {}
    }

    // Find first { ... }
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      try {
        return jsonDecode(text.substring(start, end + 1)) as Map<String, dynamic>;
      } catch (_) {}
    }
    return null;
  }

  static List<dynamic>? _extractJsonArray(String text) {
    try {
      return jsonDecode(text) as List<dynamic>;
    } catch (_) {}

    final codeBlockRegex = RegExp(r'```(?:json)?\s*([\s\S]*?)```');
    final match = codeBlockRegex.firstMatch(text);
    if (match != null) {
      try {
        return jsonDecode(match.group(1)!) as List<dynamic>;
      } catch (_) {}
    }

    final start = text.indexOf('[');
    final end = text.lastIndexOf(']');
    if (start != -1 && end != -1 && end > start) {
      try {
        return jsonDecode(text.substring(start, end + 1)) as List<dynamic>;
      } catch (_) {}
    }
    return null;
  }

  /// Extract a recipe from a URL.
  /// Routes through a Supabase Edge Function that actually fetches the page
  /// (handles TikTok, Instagram, YouTube, and any recipe website).
  static Future<Map<String, dynamic>> extractRecipeFromUrl(String url) async {
    try {
      final response = await http.post(
        Uri.parse(_extractFunctionUrl),
        headers: {'Content-Type': 'application/json', 'x-plateful-key': _appSecret},
        body: jsonEncode({'url': url}),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json is Map<String, dynamic>) {
          // Edge function signals that no recipe could be extracted.
          if (json['no_recipe'] == true) {
            final reason = json['reason'] as String? ??
                'No recipe found. The link may require a login or contain no recipe.';
            throw NoRecipeFoundException(reason);
          }
          if (!json.containsKey('error')) {
            return json;
          }
          throw Exception(json['error'] ?? 'Unknown extraction error');
        }
      }
      throw Exception('Edge function error: ${response.statusCode}');
    } on NoRecipeFoundException {
      // Re-throw so the UI can show the "no recipe" state, not a generic error.
      rethrow;
    } catch (e) {
      // Fallback: ask Claude directly (no page content, but better than nothing)
      final prompt = '''Extract or infer a recipe from this URL: $url

The URL may be from TikTok, Instagram, YouTube, or a recipe website.
IMPORTANT: Only return a recipe if you are genuinely confident one exists for this URL.
If the URL gives no meaningful dish name or content clues, return:
{"no_recipe": true, "reason": "Could not determine the recipe from the URL alone."}

Otherwise return ONLY valid JSON:
{
  "title": "Recipe name",
  "description": "Brief description",
  "image_url": null,
  "ingredients": [{"name": "ingredient", "amount": 1.0, "unit": "cup"}],
  "steps": ["Step 1", "Step 2"],
  "nutrition": {"calories": 350, "protein": 20.0, "carbs": 40.0, "fat": 15.0},
  "tags": ["tag1"],
  "servings": 4,
  "cook_time_minutes": 30
}''';

      final text = await _chat(prompt);
      final json = _extractJson(text);
      if (json != null) {
        if (json['no_recipe'] == true) {
          final reason = json['reason'] as String? ??
              'No recipe could be extracted from this link.';
          throw NoRecipeFoundException(reason);
        }
        return json;
      }
      // Final fallback: signal no-recipe rather than saving junk.
      throw const NoRecipeFoundException(
        'Could not extract a recipe from this link. '
        'Try copying the recipe text and adding it manually.',
      );
    }
  }

  /// Healthify a recipe with ingredient substitutions.
  static Future<Map<String, dynamic>> healthifyRecipe(
      Map<String, dynamic> recipe) async {
    final prompt = '''Healthify this recipe by suggesting healthier ingredient substitutions.

Recipe: ${jsonEncode(recipe)}

Return ONLY valid JSON with this exact structure:
{
  "recipe": {
    "title": "Healthier version name",
    "description": "Updated description",
    "ingredients": [{"name": "ingredient", "amount": 1.0, "unit": "cup"}],
    "steps": ["Step 1", "Step 2"],
    "nutrition": {"calories": 300, "protein": 25.0, "carbs": 30.0, "fat": 10.0}
  },
  "changes": [
    {"original": "butter", "replacement": "olive oil", "reason": "Healthier fats"}
  ],
  "caloriesSaved": 80
}

Return ONLY the JSON.''';

    final text = await _chat(prompt);
    final json = _extractJson(text);
    return json ??
        {
          'recipe': recipe,
          'changes': [],
          'caloriesSaved': 0,
        };
  }

  /// Cache key for a tailor result: recipe + diet + allergies must all match.
  static String _tailorCacheKey(
      String recipeId, String dietMode, List<String> allergies) {
    final sortedAllergies = [...allergies]..sort();
    return 'tailor_${recipeId}_${dietMode}_${sortedAllergies.join("|")}';
  }

  /// Tailor a recipe to fit a user's dietary profile and allergies.
  /// Results are cached per recipe + diet + allergies, so re-tailoring the same
  /// recipe with the same preferences returns instantly without an API call.
  static Future<Map<String, dynamic>> tailorRecipe({
    required Map<String, dynamic> recipe,
    required String dietMode,
    required List<String> allergies,
    String? extraPreferences,
    bool forceRefresh = false,
  }) async {
    final recipeId = recipe['id']?.toString() ?? '';
    final cacheKey = _tailorCacheKey(recipeId, dietMode, allergies);

    // Return cached result if available (only when no ad-hoc extra preferences)
    if (!forceRefresh &&
        recipeId.isNotEmpty &&
        (extraPreferences == null || extraPreferences.trim().isEmpty)) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString(cacheKey);
        if (cached != null) {
          final decoded = jsonDecode(cached);
          if (decoded is Map<String, dynamic>) return decoded;
        }
      } catch (_) {}
    }

    final userContext = [
      if (dietMode != 'None') 'Diet: $dietMode',
      if (allergies.isNotEmpty) 'Allergies / intolerances: ${allergies.join(', ')}',
      if (extraPreferences != null && extraPreferences.trim().isNotEmpty)
        'Other preferences: $extraPreferences',
    ].join('\n');

    final prompt = '''You are a professional chef and nutritionist. Tailor the following recipe to fit this user's profile:

USER PROFILE:
$userContext

RECIPE:
${jsonEncode(recipe)}

Analyse each ingredient and step. Suggest specific substitutions or removals where needed.
For each change, explain:
1. Why the change was made (diet/allergy reason)
2. Whether the change makes culinary sense (does it work well as a substitute?)
3. How it affects the food outcome (taste, texture, appearance)

Return ONLY valid JSON:
{
  "tailoredRecipe": {
    "title": "Updated recipe name",
    "description": "Updated description",
    "ingredients": [{"name": "ingredient", "amount": 1.0, "unit": "cup"}],
    "steps": ["Step 1", "Step 2"]
  },
  "changes": [
    {
      "original": "butter",
      "replacement": "coconut oil",
      "reason": "Dairy-free substitute",
      "culinarySense": "Works well — similar fat content and melting point",
      "outcomeImpact": "Slight coconut flavour, same texture",
      "confidence": "high"
    }
  ],
  "overallAssessment": "This recipe adapts well to your diet. The texture and flavour remain very close to the original.",
  "warnings": ["Replacing eggs may make the cake denser — consider a flax egg for better binding"]
}

confidence must be one of: "high", "medium", "low"
Return ONLY the JSON.''';

    final text = await _chat(prompt);
    final result = _extractJson(text) ?? {
      'tailoredRecipe': recipe,
      'changes': [],
      'overallAssessment': 'No changes needed for your profile.',
      'warnings': [],
    };

    // Cache the result for this recipe + diet + allergies combination
    if (recipeId.isNotEmpty &&
        (extraPreferences == null || extraPreferences.trim().isEmpty)) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(cacheKey, jsonEncode(result));
      } catch (_) {}
    }

    return result;
  }

  /// Suggest recipes based on pantry items.
  static Future<List<Map<String, dynamic>>> suggestFromPantry(
      List<String> pantryItems) async {
    final prompt = '''I have these ingredients: ${pantryItems.join(', ')}.
Suggest 3 recipes I can make with these ingredients.

Return ONLY valid JSON array:
[
  {
    "title": "Recipe name",
    "description": "Brief description",
    "missingIngredients": ["ingredient1", "ingredient2"],
    "steps": ["Step 1", "Step 2"],
    "tags": ["quick", "easy"]
  }
]

Return ONLY the JSON array.''';

    final text = await _chat(prompt);
    final list = _extractJsonArray(text);
    if (list == null) return [];
    return list.map((e) => e as Map<String, dynamic>).toList();
  }

  /// Generate a 7-day meal plan.
  static Future<Map<String, dynamic>> generateMealPlan(String dietMode) async {
    final prompt = '''Generate a 7-day meal plan for a ${dietMode == 'None' ? 'balanced' : dietMode} diet.
Include breakfast, lunch, dinner, and snack for each day.

Return ONLY valid JSON with this structure:
{
  "monday": {
    "breakfast": {"title": "...", "description": "...", "steps": ["..."]},
    "lunch": {"title": "...", "description": "...", "steps": ["..."]},
    "dinner": {"title": "...", "description": "...", "steps": ["..."]},
    "snack": {"title": "...", "description": "...", "steps": ["..."]}
  },
  "tuesday": { ... },
  "wednesday": { ... },
  "thursday": { ... },
  "friday": { ... },
  "saturday": { ... },
  "sunday": { ... }
}

Return ONLY the JSON.''';

    final text = await _chat(prompt);
    final json = _extractJson(text);
    return json ?? {};
  }
}
