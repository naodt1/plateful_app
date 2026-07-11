import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/onboarding/data/demo_recipe.dart';
import 'firebase_service.dart';

/// Seeds the onboarding demo recipe (Korean BBQ Yum Yum Rice Bowls) into the
/// user's real library after they sign up.
///
/// Signup is not always immediate (email signups only authenticate after the
/// confirmation link), so onboarding sets a pending flag and the seed runs on
/// the first authenticated Home load. It is idempotent: the flag is cleared
/// once seeded and we also skip if the demo recipe is already present.
class DemoSeedService {
  DemoSeedService._();

  static const _pendingKey = 'pending_demo_seed';
  static const _dietKey = 'pending_demo_diet';

  /// Mark that the demo recipe should be seeded after the user authenticates,
  /// remembering the diet they chose so we can save it to their profile.
  static Future<void> markPending({String diet = 'None'}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pendingKey, true);
    await prefs.setString(_dietKey, diet);
  }

  /// If a seed is pending and a user is signed in, insert the demo recipe and
  /// prime the Tailor cache so a later real Tailor is instant. Best-effort:
  /// any failure is swallowed and the flag stays set for a future retry only
  /// when the insert itself didn't run. Returns true if a recipe was seeded.
  static Future<bool> seedIfPending() async {
    final userId = FirebaseService.currentUserId;
    if (userId == null) return false;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_pendingKey) != true) return false;

    final diet = prefs.getString(_dietKey) ?? 'None';

    try {
      // Persist the chosen diet to the user's profile (best-effort).
      if (diet != 'None') {
        try {
          await FirebaseService.updateProfile({'diet_mode': diet});
        } catch (_) {}
      }

      // Skip if the user already has the demo recipe (avoids duplicates).
      final existing = await FirebaseService.getRecipes();
      final alreadyHas =
          existing.any((r) => r.sourceUrl == kDemoRecipeSourceUrl);
      if (!alreadyHas) {
        final recipe = demoRecipeForUser(userId, id: 'seed');
        final newId = await FirebaseService.saveRecipe(recipe);
        await _primeTailorCache(prefs, newId, diet);
      }
      await prefs.remove(_pendingKey);
      await prefs.remove(_dietKey);
      return !alreadyHas;
    } catch (_) {
      // Leave the flag set so we can retry on a later Home load.
      return false;
    }
  }

  /// Mirror of ClaudeService._tailorCacheKey so the pre-computed demo Tailor
  /// result is returned instantly when the user tailors the seeded recipe with
  /// the diet they picked during onboarding (no allergies).
  static Future<void> _primeTailorCache(
      SharedPreferences prefs, String recipeId, String diet) async {
    const allergies = <String>[];
    final cacheKey = 'tailor_${recipeId}_${diet}_${allergies.join("|")}';
    await prefs.setString(cacheKey, jsonEncode(demoTailorResultFor(diet)));
  }
}
