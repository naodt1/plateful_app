import 'package:flutter/foundation.dart';
import '../../models/recipe.dart';
import 'claude_service.dart';
import 'firebase_service.dart';

/// Adapts a freshly imported recipe to the user's saved diet and allergies, so
/// the recipe arrives already usable instead of requiring a trip to Tailor.
///
/// The pre-adaptation version is preserved on the returned [Recipe] so the
/// detail screen can always show the original.
class RecipeAdapter {
  RecipeAdapter._();

  /// The user's diet + allergies, or null when they have no restrictions.
  static Future<({String diet, List<String> allergies})?> profileRestrictions() async {
    try {
      final profile = await FirebaseService.getProfile();
      if (profile == null) return null;

      final diet = (profile['diet_mode'] as String?) ?? 'None';

      final raw = profile['allergies'];
      var allergies = <String>[];
      if (raw is List) {
        allergies = raw.map((e) => e.toString()).toList();
      } else if (raw is String && raw.trim().isNotEmpty) {
        allergies = raw
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }

      if (diet == 'None' && allergies.isEmpty) return null;
      return (diet: diet, allergies: allergies);
    } catch (e) {
      debugPrint('RecipeAdapter: profile lookup failed: $e');
      return null;
    }
  }

  /// Returns [recipe] rewritten for the user's diet/allergies, or the original
  /// recipe unchanged when there's nothing to adapt or the AI call fails.
  /// Never throws — a failed adaptation must not block the import.
  static Future<Recipe> adaptOnImport(Recipe recipe) async {
    final restrictions = await profileRestrictions();
    if (restrictions == null) return recipe;

    try {
      final result = await ClaudeService.tailorRecipe(
        recipe: recipe.toJson(),
        dietMode: restrictions.diet,
        allergies: restrictions.allergies,
      );

      final tailored = result['tailoredRecipe'];
      if (tailored is! Map<String, dynamic>) return recipe;

      final ingredientsRaw = tailored['ingredients'];
      final steps = (tailored['steps'] as List?)
              ?.map((e) => e.toString())
              .where((e) => e.trim().isNotEmpty)
              .toList() ??
          const <String>[];

      if (ingredientsRaw is! List || ingredientsRaw.isEmpty || steps.isEmpty) {
        return recipe; // never replace a good recipe with an empty one
      }

      final ingredients = ingredientsRaw
          .whereType<Map<String, dynamic>>()
          .map(Ingredient.fromJson)
          .toList();
      if (ingredients.isEmpty) return recipe;

      final changes = (result['changes'] as List?) ?? const [];
      // Nothing actually changed — keep it as a normal, unbadged recipe.
      if (changes.isEmpty) return recipe;

      final label = restrictions.diet != 'None'
          ? restrictions.diet
          : restrictions.allergies.join(', ');

      return recipe.copyWith(
        title: (tailored['title'] as String?)?.trim().isNotEmpty == true
            ? tailored['title'] as String
            : recipe.title,
        description:
            (tailored['description'] as String?)?.trim().isNotEmpty == true
                ? tailored['description'] as String
                : recipe.description,
        ingredients: ingredients,
        steps: steps,
        adaptedFor: label,
        originalTitle: recipe.title,
        originalIngredients: recipe.ingredients,
        originalSteps: recipe.steps,
        adaptationSummary: (result['overallAssessment'] as String?)?.trim(),
      );
    } catch (e) {
      debugPrint('RecipeAdapter: adaptation failed, keeping original: $e');
      return recipe;
    }
  }
}
