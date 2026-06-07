import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/providers/recipe_providers.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../widgets/recipe_card.dart';
import '../widgets/collections_row.dart';
import '../widgets/pantry_banner.dart';
import '../../recipe/screens/add_recipe_screen.dart';

// Aliases to the shared providers so the rest of this file is unchanged.
final _recipesProvider = recipesProvider;
final _collectionsProvider = collectionsProvider;
final _profileProvider = profileProvider;

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _showAddRecipeSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        maxChildSize: 0.97,
        minChildSize: 0.5,
        builder: (_, scrollController) => AddRecipeSheet(scrollController: scrollController),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(_recipesProvider);
    final collectionsAsync = ref.watch(_collectionsProvider);
    final profileAsync = ref.watch(_profileProvider);
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(_recipesProvider);
            ref.invalidate(_collectionsProvider);
            ref.invalidate(_profileProvider);
          },
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: profileAsync.when(
                          data: (profile) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _greeting(),
                                style: AppTextStyles.bodyMedium
                                    .copyWith(color: colors.textSecondary),
                              ),
                              Text(
                                profile?['display_name'] ?? 'Chef',
                                style: AppTextStyles.headingLarge,
                              ),
                            ],
                          ),
                          loading: () => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SkeletonText(width: 100),
                              const SizedBox(height: 6),
                              const SkeletonText(width: 150, height: 20),
                            ],
                          ),
                          error: (_, __) => Text(_greeting(),
                              style: AppTextStyles.headingLarge),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.go('/profile'),
                        child: profileAsync.when(
                          data: (profile) => CircleAvatar(
                            radius: 22,
                            backgroundColor: AppColors.primary,
                            backgroundImage: profile?['avatar_url'] != null
                                ? NetworkImage(profile!['avatar_url'])
                                : null,
                            child: profile?['avatar_url'] == null
                                ? Text(
                                    (profile?['display_name'] as String? ?? 'C')
                                        .substring(0, 1)
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  )
                                : null,
                          ),
                          loading: () => const SkeletonLoader(
                              width: 44, height: 44, borderRadius: 22),
                          error: (_, __) => const CircleAvatar(
                            radius: 22,
                            backgroundColor: AppColors.primary,
                            child: Icon(Icons.person,
                                color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(),
                ),
              ),

              // Search bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GestureDetector(
                    onTap: () => context.push('/recipes'),
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search,
                              color: colors.textSecondary, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'Search recipes...',
                            style: AppTextStyles.bodyMedium
                                .copyWith(color: colors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 100.ms),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 28)),

              // Recently Saved
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Recently Saved',
                              style: AppTextStyles.headingMedium),
                          GestureDetector(
                            onTap: () => context.push('/recipes'),
                            child: Text(
                              'See all',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 248,
                      child: recipesAsync.when(
                        data: (recipes) {
                          if (recipes.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.bookmark_border,
                                      size: 40, color: colors.textSecondary),
                                  const SizedBox(height: 8),
                                  Text('No recipes yet',
                                      style: AppTextStyles.bodyMedium.copyWith(
                                          color: colors.textSecondary)),
                                  GestureDetector(
                                    onTap: () => context.push('/recipe/add'),
                                    child: Text(
                                      'Add your first recipe →',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: recipes.length,
                            itemBuilder: (context, index) => RecipeCard(
                              recipe: recipes[index],
                              onTap: () => context.push(
                                '/recipe/${recipes[index].id}',
                                extra: recipes[index],
                              ),
                            ),
                          );
                        },
                        loading: () => ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: 3,
                          itemBuilder: (_, __) => const SkeletonRecipeCard(),
                        ),
                        error: (e, _) => Center(
                          child: Text('Error loading recipes',
                              style: AppTextStyles.bodySmall),
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 150.ms),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Pantry banner
              SliverToBoxAdapter(
                child: PantryBanner(
                  onTap: () => context.go('/pantry'),
                ).animate().fadeIn(delay: 200.ms),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Collections
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Collections', style: AppTextStyles.headingMedium),
                          GestureDetector(
                            onTap: () => context.push('/collections'),
                            child: Text(
                              'See all',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    collectionsAsync.when(
                      data: (collections) => CollectionsRow(
                        collections: collections,
                        onViewAll: () => context.push('/collections'),
                      ),
                      loading: () => SizedBox(
                        height: 80,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: 3,
                          itemBuilder: (_, __) => Container(
                            width: 120,
                            margin: const EdgeInsets.only(right: 12),
                            child: const SkeletonLoader(
                                width: 120, height: 80, borderRadius: 16),
                          ),
                        ),
                      ),
                      error: (_, __) =>
                          const SizedBox(height: 80),
                    ),
                  ],
                ).animate().fadeIn(delay: 250.ms),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddRecipeSheet(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
