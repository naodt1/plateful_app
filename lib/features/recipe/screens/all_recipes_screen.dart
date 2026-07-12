import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/providers/recipe_providers.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../models/recipe.dart';
import '../../../core/utils/error_messages.dart';

enum _DateFilter { all, today, week, month }

extension _DateFilterLabel on _DateFilter {
  String get label => switch (this) {
        _DateFilter.all => 'All',
        _DateFilter.today => 'Today',
        _DateFilter.week => 'This Week',
        _DateFilter.month => 'This Month',
      };
}

class AllRecipesScreen extends ConsumerStatefulWidget {
  const AllRecipesScreen({super.key});

  @override
  ConsumerState<AllRecipesScreen> createState() => _AllRecipesScreenState();
}

class _AllRecipesScreenState extends ConsumerState<AllRecipesScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  _DateFilter _dateFilter = _DateFilter.all;
  bool _newestFirst = true;
  bool _favoritesOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesDate(DateTime created) {
    final now = DateTime.now();
    switch (_dateFilter) {
      case _DateFilter.all:
        return true;
      case _DateFilter.today:
        return created.year == now.year &&
            created.month == now.month &&
            created.day == now.day;
      case _DateFilter.week:
        return now.difference(created).inDays < 7;
      case _DateFilter.month:
        return created.year == now.year && created.month == now.month;
    }
  }

  List<Recipe> _filter(List<Recipe> recipes) {
    final q = _query.trim().toLowerCase();
    var list = recipes.where((r) {
      if (_favoritesOnly && !r.favorite) return false;
      if (!_matchesDate(r.createdAt)) return false;
      if (q.isEmpty) return true;
      return r.title.toLowerCase().contains(q) ||
          r.description.toLowerCase().contains(q) ||
          r.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();
    list.sort((a, b) => _newestFirst
        ? b.createdAt.compareTo(a.createdAt)
        : a.createdAt.compareTo(b.createdAt));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final recipesAsync = ref.watch(recipesProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        title: Text('All Recipes', style: AppTextStyles.headingMedium),
        actions: [
          IconButton(
            tooltip: _favoritesOnly ? 'Showing favorites' : 'Show favorites',
            icon: Icon(
              _favoritesOnly ? Icons.favorite : Icons.favorite_border,
              color:
                  _favoritesOnly ? const Color(0xFFE5533D) : colors.textPrimary,
              size: 20,
            ),
            onPressed: () =>
                setState(() => _favoritesOnly = !_favoritesOnly),
          ),
          IconButton(
            tooltip: _newestFirst ? 'Newest first' : 'Oldest first',
            icon: Icon(
              _newestFirst ? Icons.arrow_downward : Icons.arrow_upward,
              color: colors.textPrimary,
              size: 20,
            ),
            onPressed: () => setState(() => _newestFirst = !_newestFirst),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: colors.textSecondary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        hintText: 'Search recipes…',
                        hintStyle: TextStyle(color: colors.textSecondary),
                        border: InputBorder.none,
                        isCollapsed: true,
                      ),
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: colors.textPrimary),
                    ),
                  ),
                  if (_query.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      child: Icon(Icons.close,
                          color: colors.textSecondary, size: 18),
                    ),
                ],
              ),
            ),
          ),

          // Date filter chips
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: _DateFilter.values.map((f) {
                final selected = _dateFilter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _dateFilter = f),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : colors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: selected ? AppColors.primary : colors.border),
                      ),
                      child: Text(
                        f.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : colors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),

          // Results
          Expanded(
            child: recipesAsync.when(
              loading: () => ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: 6,
                itemBuilder: (_, __) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: SkeletonLoader(
                      width: double.infinity, height: 88, borderRadius: 16),
                ),
              ),
              error: (e, _) => Center(
                  child: Text(friendlyError(e), style: AppTextStyles.bodySmall)),
              data: (recipes) {
                final filtered = _filter(recipes);

                if (recipes.isEmpty) {
                  return EmptyState(
                    icon: Icons.bookmark_border,
                    title: 'No recipes yet',
                    subtitle: 'Recipes you save will appear here.',
                    ctaLabel: 'Add a recipe',
                    onCta: () => context.push('/recipe/add'),
                  );
                }
                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.search_off,
                    title: 'No matches',
                    subtitle: _query.isNotEmpty
                        ? 'No recipes match "$_query".'
                        : _favoritesOnly
                            ? 'No favorites yet — tap the heart on a recipe.'
                            : 'No recipes in this time range.',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final recipe = filtered[index];
                    return _RecipeRow(
                      recipe: recipe,
                      colors: colors,
                      onTap: () => context.push('/recipe/${recipe.id}',
                          extra: recipe),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipeRow extends StatelessWidget {
  final Recipe recipe;
  final AppColorScheme colors;
  final VoidCallback onTap;

  const _RecipeRow({
    required this.recipe,
    required this.colors,
    required this.onTap,
  });

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return DateFormat('MMM d, y').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Hero(
              tag: 'recipe-image-${recipe.id}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 68,
                  height: 68,
                  child: hasImage
                      ? CachedNetworkImage(
                          imageUrl: recipe.imageUrl!,
                          fit: BoxFit.cover,
                          fadeInDuration: const Duration(milliseconds: 350),
                          placeholder: (_, __) => Container(color: colors.border),
                          errorWidget: (_, __, ___) => _imgFallback(),
                        )
                      : _imgFallback(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    style: AppTextStyles.labelLarge
                        .copyWith(color: colors.textPrimary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.schedule,
                          size: 12, color: colors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(recipe.createdAt),
                        style: TextStyle(
                            fontSize: 12, color: colors.textSecondary),
                      ),
                      if (recipe.tags.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: colors.border,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              recipe.tags.first,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 10, color: colors.textSecondary),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (recipe.favorite) ...[
              const Icon(Icons.favorite, size: 15, color: Color(0xFFE5533D)),
              const SizedBox(width: 6),
            ],
            Icon(Icons.chevron_right, color: colors.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _imgFallback() => Container(
        color: AppColors.primary.withValues(alpha: 0.1),
        child: const Icon(Icons.restaurant, color: AppColors.primary, size: 26),
      );
}
