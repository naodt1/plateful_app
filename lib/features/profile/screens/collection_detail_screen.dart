import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../models/recipe.dart';
import '../../../models/collection.dart';
import '../../home/widgets/recipe_card.dart';

final _collectionRecipesProvider =
    FutureProvider.autoDispose.family<List<Recipe>, String>((ref, id) {
  return SupabaseService.getCollectionRecipes(id);
});

class CollectionDetailScreen extends ConsumerWidget {
  final String collectionId;
  final String collectionName;

  const CollectionDetailScreen({
    super.key,
    required this.collectionId,
    required this.collectionName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final recipesAsync = ref.watch(_collectionRecipesProvider(collectionId));

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        title: Text(collectionName, style: AppTextStyles.headingMedium),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline, color: AppColors.error),
            tooltip: 'Delete collection',
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: recipesAsync.when(
        data: (recipes) {
          if (recipes.isEmpty) {
            return EmptyState(
              icon: Icons.collections_bookmark_outlined,
              title: 'Nothing here yet',
              subtitle:
                  'Open any recipe and tap ⋯ → "Save to Collection" to add it here.',
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.75,
            ),
            itemCount: recipes.length,
            itemBuilder: (context, index) {
              final recipe = recipes[index];
              return GestureDetector(
                onTap: () => context.push('/recipe/${recipe.id}'),
                onLongPress: () =>
                    _confirmRemove(context, ref, recipe),
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16)),
                          child: recipe.imageUrl != null &&
                                  recipe.imageUrl!.isNotEmpty
                              ? Image.network(
                                  recipe.imageUrl!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  errorBuilder: (_, __, ___) =>
                                      _Placeholder(colors: colors),
                                )
                              : _Placeholder(colors: colors),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                recipe.title,
                                style: AppTextStyles.labelLarge
                                    .copyWith(fontSize: 13),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Row(
                                children: [
                                  Icon(Icons.format_list_bulleted,
                                      size: 11, color: colors.textSecondary),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${recipe.ingredients.length} ingredients',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: colors.textSecondary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.75,
          ),
          itemCount: 4,
          itemBuilder: (_, __) => const SkeletonLoader(
              width: double.infinity,
              height: double.infinity,
              borderRadius: 16),
        ),
        error: (e, _) => Center(
            child: Text('Error: $e', style: AppTextStyles.bodySmall)),
      ),
    );
  }

  Future<void> _confirmRemove(
      BuildContext context, WidgetRef ref, Recipe recipe) async {
    final colors = AppColors.of(context);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('"${recipe.title}"',
                style: AppTextStyles.headingMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('Remove from this collection?',
                style: TextStyle(color: colors.textSecondary)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    side: BorderSide(color: colors.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Remove'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    await SupabaseService.removeRecipeFromCollection(
        collectionId, recipe.id);
    ref.invalidate(_collectionRecipesProvider(collectionId));
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete collection?'),
        content: Text(
            '"$collectionName" and all its recipe links will be removed. The recipes themselves stay in your library.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await SupabaseService.deleteCollection(collectionId);
    if (context.mounted) context.pop();
  }
}

class _Placeholder extends StatelessWidget {
  final AppColorScheme colors;
  const _Placeholder({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: colors.surface,
      child: Center(
        child: Icon(Icons.restaurant_menu,
            size: 32, color: colors.border),
      ),
    );
  }
}
