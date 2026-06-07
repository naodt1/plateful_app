import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_service.dart';
import '../../models/recipe.dart';
import '../../models/collection.dart';

/// Shared recipe + collection providers used across the app so that any screen
/// (add, edit, delete, import) can refresh the home screen by invalidating them.

final recipesProvider = FutureProvider<List<Recipe>>((ref) async {
  return SupabaseService.getRecipes();
});

final collectionsProvider = FutureProvider<List<Collection>>((ref) async {
  return SupabaseService.getCollections();
});

final profileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  return SupabaseService.getProfile();
});

/// Invalidate every recipe-related provider so screens re-fetch fresh data.
void refreshRecipeData(WidgetRef ref) {
  ref.invalidate(recipesProvider);
  ref.invalidate(collectionsProvider);
}
