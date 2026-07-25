import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/in_app_web_view.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/providers/recipe_providers.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/claude_service.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../models/recipe.dart';
import '../../../models/collection.dart';
import '../../../models/grocery_item.dart';
import '../../../models/meal_plan.dart';
import '../widgets/ingredient_row.dart';
import '../widgets/nutrition_card.dart';
import '../widgets/healthify_sheet.dart';
import 'add_recipe_screen.dart';
import '../widgets/servings_adjuster.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../subscription/pro_gate.dart';
import '../../../core/providers/subscription_provider.dart';
import '../../../core/utils/error_messages.dart';

class RecipeDetailScreen extends ConsumerStatefulWidget {
  final String recipeId;

  /// Optional: pass the already-loaded recipe so the screen renders instantly
  /// (no loading skeleton mid-transition → smooth Hero animation).
  final Recipe? initialRecipe;

  const RecipeDetailScreen({
    super.key,
    required this.recipeId,
    this.initialRecipe,
  });

  @override
  ConsumerState<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen> {
  Recipe? _recipe;
  bool _isLoading = true;
  int _servings = 4;

  /// When the recipe was auto-adapted on import, lets the user flip back to the
  /// recipe as originally written. View-only — the stored recipe is unchanged.
  bool _showOriginal = false;

  /// The version currently on screen: the adapted recipe, or the original when
  /// the user has toggled it.
  Recipe? get _displayRecipe {
    final r = _recipe;
    if (r == null || !_showOriginal || !r.isAdapted) return r;
    return r.copyWith(
      title: r.originalTitle,
      ingredients: r.originalIngredients,
      steps: r.originalSteps,
    );
  }

  final ScrollController _scrollController = ScrollController();
  // 0 = no blur (top), 1 = fully blurred. A ValueNotifier so only the blur
  // layer rebuilds on scroll — not the whole screen (keeps scrolling smooth).
  final ValueNotifier<double> _blur = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Seed with the passed recipe for an instant first frame.
    if (widget.initialRecipe != null) {
      _recipe = widget.initialRecipe;
      _servings = widget.initialRecipe!.servings;
      _isLoading = false;
    }
    _loadRecipe();
  }

  void _onScroll() {
    // Ramp blur in over the first ~220px of scroll.
    const maxScroll = 220.0;
    final offset = _scrollController.offset.clamp(0.0, maxScroll);
    final next = offset / maxScroll;
    if ((next - _blur.value).abs() > 0.02) {
      _blur.value = next; // no setState → no full-tree rebuild
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _blur.dispose();
    super.dispose();
  }

  Future<void> _loadRecipe() async {
    try {
      final recipe = await FirebaseService.getRecipe(widget.recipeId);
      if (mounted) {
        setState(() {
          if (recipe != null) {
            _recipe = recipe;
            // Keep the user's current servings if they already adjusted.
            if (widget.initialRecipe == null) _servings = recipe.servings;
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  /// If [name] is an ingredient that replaced another during adaptation,
  /// returns the ingredient it replaced. Null while viewing the original.
  String? _swappedFrom(String name) {
    final r = _recipe;
    if (_showOriginal || r == null || !r.isAdapted) return null;
    final swaps = r.adaptationSwaps;
    if (swaps == null || swaps.isEmpty) return null;

    final n = name.toLowerCase().trim();
    for (final s in swaps) {
      final to = s.to.toLowerCase().trim();
      if (to.isEmpty) continue;
      if (n == to || n.contains(to) || to.contains(n)) return s.from;
    }
    return null;
  }

  List<Ingredient> get _scaledIngredients {
    final recipe = _displayRecipe;
    if (recipe == null) return [];
    final originalServings = recipe.servings;
    if (originalServings == 0) return recipe.ingredients;
    final scale = _servings / originalServings;
    return recipe.ingredients
        .map((i) => i.copyWith(amount: i.amount * scale))
        .toList();
  }

  Future<void> _toggleFavorite() async {
    final r = _recipe;
    if (r == null) return;
    final next = !r.favorite;
    setState(() => _recipe = r.copyWith(favorite: next));
    try {
      await FirebaseService.setFavorite(r.id, next);
      refreshRecipeData(ref);
    } catch (e) {
      if (mounted) {
        setState(() => _recipe = r); // revert on failure
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  Future<void> _showHealthifySheet() async {
    final recipe = _recipe;
    if (recipe == null) return;
    if (!await ProGate.ensurePro(context)) return; // Pro-only
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, __) => HealthifySheet(recipe: recipe),
      ),
    );
  }

  Future<void> _showTailorSheet() async {
    final recipe = _recipe;
    if (recipe == null) return;
    if (!await ProGate.ensurePro(context)) return; // Pro-only
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.58,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, controller) =>
            TailorSheet(recipe: recipe, scrollController: controller),
      ),
    );
  }

  void _startCooking() {
    final recipe = _recipe;
    if (recipe == null || recipe.steps.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => CookingModeScreen(
        steps: recipe.steps,
        title: recipe.title,
        ingredients: _scaledIngredients,
      ),
    ));
  }

  Future<void> _addToGroceryList() async {
    final recipe = _recipe;
    if (recipe == null) return;
    final userId = FirebaseService.currentUserId ?? '';
    for (final ingredient in _scaledIngredients) {
      await FirebaseService.addGroceryItem(GroceryItem(
        id: const Uuid().v4(),
        userId: userId,
        name: ingredient.name,
        category: 'Other',
        quantity: '${_formatAmount(ingredient.amount)} ${ingredient.unit}'.trim(),
        checked: false,
        recipeId: recipe.id,
        createdAt: DateTime.now(),
      ));
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Added to grocery list!'),
          backgroundColor: AppColors.success));
    }
  }

  Future<void> _addToMealPlan() async {
    if (_recipe == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MealPlanPickerSheet(recipe: _recipe!),
    );
  }

  String _formatAmount(double amount) {
    if (amount == amount.roundToDouble()) return amount.round().toString();
    return amount.toStringAsFixed(1);
  }

  Future<void> _addToCollection() async {
    final recipe = _recipe;
    if (recipe == null) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddToCollectionSheet(recipeId: recipe.id),
    );
    // The sheet may have toggled Favorites (the virtual collection); pull the
    // fresh flag so the app-bar heart stays in sync.
    final updated = await FirebaseService.getRecipe(recipe.id);
    if (mounted && updated != null && updated.favorite != _recipe?.favorite) {
      setState(() => _recipe = _recipe?.copyWith(favorite: updated.favorite));
      refreshRecipeData(ref);
    }
  }

  Future<void> _editRecipe() async {
    final recipe = _recipe;
    if (recipe == null) return;
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        maxChildSize: 0.97,
        minChildSize: 0.5,
        builder: (_, controller) =>
            AddRecipeSheet(existingRecipe: recipe, scrollController: controller),
      ),
    );
    if (changed == true) {
      _loadRecipe();
      refreshRecipeData(ref); // refresh home screen
    }
  }

  Future<void> _confirmDelete() async {
    final recipe = _recipe;
    if (recipe == null) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete recipe?',
      message: '"${recipe.title}" will be permanently removed.',
      confirmLabel: 'Delete',
      destructive: true,
      icon: Icons.delete_outline,
    );
    if (!confirmed) return;
    try {
      await FirebaseService.deleteRecipe(recipe.id);
      refreshRecipeData(ref); // refresh home screen
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recipe deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const _LoadingSkeleton();
    final recipe = _displayRecipe;
    if (recipe == null) {
      return Scaffold(
        appBar: AppBar(leading: const BackButton()),
        body: const Center(child: Text('Recipe not found')),
      );
    }

    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // ── Hero ──────────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 272,
            pinned: true,
            backgroundColor: colors.bg,
            leading: GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 18),
              ),
            ),
            actions: [
              if (_recipe != null)
                Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    tooltip: _recipe!.favorite
                        ? 'Remove from Favorites'
                        : 'Add to Favorites',
                    icon: Icon(
                      _recipe!.favorite
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: _recipe!.favorite
                          ? const Color(0xFFE5533D)
                          : Colors.white,
                      size: 20,
                    ),
                    onPressed: _toggleFavorite,
                  ),
                ),
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz, color: Colors.white, size: 20),
                  onSelected: (v) {
                    if (v == 'edit') _editRecipe();
                    if (v == 'delete') _confirmDelete();
                    if (v == 'collection') _addToCollection();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'collection',
                      child: Row(children: [
                        Icon(Icons.collections_bookmark_outlined, size: 18),
                        SizedBox(width: 10),
                        Text('Save to Collection'),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 10),
                        Text('Edit recipe'),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                        SizedBox(width: 10),
                        Text('Delete', style: TextStyle(color: AppColors.error)),
                      ]),
                    ),
                  ],
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'recipe-image-${recipe.id}',
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: recipe.imageUrl!,
                            fit: BoxFit.cover,
                            fadeInDuration: const Duration(milliseconds: 350),
                            placeholder: (_, __) =>
                                Container(color: colors.surface),
                            errorWidget: (_, __, ___) =>
                                _HeroPlaceholder(colors: colors),
                          )
                        : _HeroPlaceholder(colors: colors),
                    // Progressive blur as the user scrolls — adds depth.
                    // Only this layer rebuilds (ValueListenableBuilder), so the
                    // scroll stays smooth.
                    Positioned.fill(
                      child: ValueListenableBuilder<double>(
                        valueListenable: _blur,
                        builder: (context, blur, _) {
                          if (blur <= 0) return const SizedBox.shrink();
                          return BackdropFilter(
                            filter: ui.ImageFilter.blur(
                              sigmaX: blur * 12,
                              sigmaY: blur * 12,
                            ),
                            child: Container(
                              color: Colors.black.withValues(alpha: blur * 0.15),
                            ),
                          );
                        },
                      ),
                    ),
                    // Subtle gradient so the back/menu buttons stay legible.
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.25),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.15),
                          ],
                          stops: const [0.0, 0.4, 1.0],
                        ),
                      ),
                    ),
                    // Rounded lip overlapping the image bottom so the content
                    // sheet visibly curves over the photo.
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: 24,
                        decoration: BoxDecoration(
                          color: colors.bg,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(28),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                color: colors.bg,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Title & description ────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(recipe.title,
                                style: AppTextStyles.displayMedium,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis)
                            .animate()
                            .fadeIn(),

                        // Auto-adapted chip + flip back to the original.
                        if (_recipe?.isAdapted == true) ...[
                          const SizedBox(height: 14),
                          _AdaptedBanner(
                            adaptedFor: _recipe!.adaptedFor!,
                            summary: _recipe!.adaptationSummary,
                            showingOriginal: _showOriginal,
                            colors: colors,
                            onToggle: () => setState(
                                () => _showOriginal = !_showOriginal),
                          ),
                        ],

                        const SizedBox(height: 10),

                        // Tags (below title)
                        if (recipe.tags.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: recipe.tags.take(3).map((tag) =>
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: colors.surface,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: colors.border),
                                ),
                                child: Text(tag,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: colors.textSecondary,
                                        fontWeight: FontWeight.w500)),
                              )).toList(),
                          ),
                        const SizedBox(height: 8),

                        // Description with "see more"
                        if (recipe.description.isNotEmpty)
                          _ExpandableDescription(
                            text: recipe.description,
                            sourceUrl: recipe.sourceUrl,
                            colors: colors,
                          ),

                        const SizedBox(height: 20),

                        // ── AI Action buttons ─────────────────────────────
                        Row(
                          children: [
                            Expanded(
                              child: _AiActionButton(
                                icon: Icons.tune_rounded,
                                label: 'Tailor',
                                color: AppColors.primary,
                                showProBadge: !ref.watch(isProProvider),
                                onTap: _showTailorSheet,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _AiActionButton(
                                icon: Icons.eco_rounded,
                                label: 'Healthify',
                                color: AppColors.accent,
                                showProBadge: !ref.watch(isProProvider),
                                onTap: _showHealthifySheet,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // ── Utility row ───────────────────────────────────
                        Row(
                          children: [
                            Expanded(
                              child: _UtilButton(
                                icon: Icons.shopping_cart_outlined,
                                label: 'Add to Grocery',
                                onTap: _addToGroceryList,
                                colors: colors,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _UtilButton(
                                icon: Icons.calendar_today_outlined,
                                label: 'Add to Plan',
                                onTap: _addToMealPlan,
                                colors: colors,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // ── Servings ──────────────────────────────────────
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Servings', style: AppTextStyles.labelLarge),
                              ServingsAdjuster(
                                servings: _servings,
                                onDecrement: () =>
                                    setState(() => _servings = (_servings - 1).clamp(1, 99)),
                                onIncrement: () => setState(() => _servings++),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                      ],
                    ),
                  ),

                  // ── Ingredients ────────────────────────────────────────────
                  _SectionHeader(
                    label: 'Ingredients',
                    count: _scaledIngredients.length,
                    trailing: _scaledIngredients.isNotEmpty
                        ? _SectionIconButton(
                            icon: Icons.shopping_cart_outlined,
                            tooltip: 'Add all to grocery',
                            onTap: _addToGroceryList,
                            colors: colors,
                          )
                        : null,
                    colors: colors,
                  ),
                  const SizedBox(height: 12),
                  if (_scaledIngredients.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text('No ingredients listed.',
                          style: TextStyle(color: colors.textSecondary)),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _CollapsibleIngredientList(
                        ingredients: _scaledIngredients,
                        colors: colors,
                        swappedFrom: _swappedFrom,
                      ),
                    ),

                  const SizedBox(height: 28),

                  // ── Steps ──────────────────────────────────────────────────
                  _SectionHeader(
                    label: 'Steps',
                    count: recipe.steps.length,
                    trailing: recipe.steps.isNotEmpty
                        ? GestureDetector(
                            onTap: _startCooking,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
                                  SizedBox(width: 4),
                                  Text('Start Cooking',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          )
                        : null,
                    colors: colors,
                  ),
                  const SizedBox(height: 12),
                  if (recipe.steps.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text('No steps listed.',
                          style: TextStyle(color: colors.textSecondary)),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: recipe.steps.asMap().entries
                            .map((e) => _StepTile(number: e.key + 1, text: e.value, colors: colors))
                            .toList(),
                      ),
                    ),

                  const SizedBox(height: 28),

                  // ── Nutrition ──────────────────────────────────────────────
                  if (recipe.nutrition != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Text('Macros', style: AppTextStyles.headingMedium),
                          const SizedBox(width: 7),
                          _MacroInfoButton(colors: colors),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: NutritionGrid(nutrition: recipe.nutrition!),
                    ),
                    const SizedBox(height: 28),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Expandable description ────────────────────────────────────────────────────
class _ExpandableDescription extends StatefulWidget {
  final String text;
  final String? sourceUrl;
  final AppColorScheme colors;

  const _ExpandableDescription(
      {required this.text, this.sourceUrl, required this.colors});

  @override
  State<_ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<_ExpandableDescription> {
  static const int _limit = 120;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isLong = widget.text.length > _limit;
    final displayText = !isLong || _expanded
        ? widget.text
        : '${widget.text.substring(0, _limit).trimRight()}...';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(displayText,
            style: AppTextStyles.bodyMedium.copyWith(color: widget.colors.textSecondary)),
        if (isLong && !_expanded) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _expanded = true),
                child: Text('See more',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
              if (widget.sourceUrl != null && widget.sourceUrl!.isNotEmpty) ...[
                Text('  ·  ',
                    style: TextStyle(color: widget.colors.textSecondary, fontSize: 13)),
                GestureDetector(
                  onTap: () => InAppWebView.open(context, widget.sourceUrl!,
                      title: 'Recipe Source'),
                  child: Text('Open source ↗',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
        ],
        if (_expanded && widget.sourceUrl != null && widget.sourceUrl!.isNotEmpty) ...[
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => InAppWebView.open(context, widget.sourceUrl!,
                title: 'Recipe Source'),
            child: Text('Open source ↗',
                style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ],
    );
  }
}

// ── AI action button ──────────────────────────────────────────────────────────
class _AiActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool showProBadge;

  const _AiActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.showProBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
            if (showProBadge)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.lock_outline,
                    color: Colors.white70, size: 16),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Utility button ────────────────────────────────────────────────────────────
class _UtilButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final AppColorScheme colors;

  const _UtilButton(
      {required this.icon, required this.label, required this.onTap, required this.colors});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: colors.textSecondary),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary)),
          ],
        ),
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  final int? count;
  final Widget? trailing;
  final AppColorScheme colors;

  const _SectionHeader(
      {required this.label, this.count, this.trailing, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(label, style: AppTextStyles.headingMedium),
          if (count != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('$count',
                  style: TextStyle(
                      fontSize: 12,
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w500)),
            ),
          ],
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Banner shown when a recipe was automatically rewritten for the user's diet
/// on import, with a switch back to the recipe as originally written.
/// Compact chip shown when a recipe was rewritten for the user's diet on
/// import. Kept to a single line to sit alongside the tag row; the full
/// explanation lives behind a tap so it never dominates the page.
class _AdaptedBanner extends StatelessWidget {
  final String adaptedFor;
  final String? summary;
  final bool showingOriginal;
  final AppColorScheme colors;
  final VoidCallback onToggle;

  const _AdaptedBanner({
    required this.adaptedFor,
    required this.summary,
    required this.showingOriginal,
    required this.colors,
    required this.onToggle,
  });

  static const _dietEmoji = {
    'Vegan': '🌱',
    'Vegetarian': '🥦',
    'Keto': '🥩',
    'Paleo': '🦴',
    'Gluten-Free': '🌾',
    'Halal': '☪️',
  };

  String get _emoji => _dietEmoji[adaptedFor] ?? '🍽️';

  void _showDetail(BuildContext context) {
    final text = summary?.trim();
    if (text == null || text.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
            24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text(_emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Adapted for $adaptedFor',
                      style: AppTextStyles.headingMedium),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(text,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: colors.textSecondary, height: 1.5)),
            const SizedBox(height: 16),
            Text(
              'Your original recipe is kept — tap “View original” any time.',
              style:
                  AppTextStyles.caption.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: 22),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: const Text('Got it',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSummary = (summary?.trim().isNotEmpty ?? false);
    final tint = showingOriginal ? colors.surface : AppColors.primary;

    return Row(
      children: [
        Flexible(
          child: GestureDetector(
            onTap: showingOriginal ? null : () => _showDetail(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: showingOriginal
                    ? colors.surface
                    : tint.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: showingOriginal
                      ? colors.border
                      : tint.withValues(alpha: 0.22),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showingOriginal)
                    Icon(Icons.history_rounded,
                        size: 13, color: colors.textSecondary)
                  else
                    Text(_emoji, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      showingOriginal ? 'Original' : 'Adapted · $adaptedFor',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: showingOriginal
                            ? colors.textSecondary
                            : AppColors.primary,
                      ),
                    ),
                  ),
                  if (!showingOriginal && hasSummary) ...[
                    const SizedBox(width: 5),
                    Icon(Icons.info_outline_rounded,
                        size: 12,
                        color: AppColors.primary.withValues(alpha: 0.7)),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: onToggle,
          behavior: HitTestBehavior.opaque,
          child: Text(
            showingOriginal ? 'View adapted' : 'View original',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
              decoration: TextDecoration.underline,
              decorationColor: colors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Small "?" beside the Macros title that explains where the numbers come from.
class _MacroInfoButton extends StatelessWidget {
  final AppColorScheme colors;
  const _MacroInfoButton({required this.colors});

  void _show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
            24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text('Where these macros come from',
                style: AppTextStyles.headingMedium),
            const SizedBox(height: 16),
            _MacroInfoLine(
              icon: Icons.menu_book_rounded,
              title: 'From the recipe',
              body:
                  'If the original recipe lists nutrition, Plateful uses those numbers as-is.',
              colors: colors,
            ),
            const SizedBox(height: 14),
            _MacroInfoLine(
              icon: Icons.soup_kitchen_rounded,
              title: 'Intelligently estimated',
              body:
                  'If it doesn\'t, Plateful\'s intelligence estimates the macros from the ingredients and serving size.',
              colors: colors,
            ),
            const SizedBox(height: 16),
            Text(
              'Either way, treat them as a close approximation — not a lab measurement.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: 22),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: const Text('Got it',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _show(context),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 18,
        height: 18,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: colors.textSecondary, width: 1.4),
        ),
        child: Text('?',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: colors.textSecondary,
                height: 1.0)),
      ),
    );
  }
}

class _MacroInfoLine extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final AppColorScheme colors;

  const _MacroInfoLine({
    required this.icon,
    required this.title,
    required this.body,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 19, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700, color: colors.textPrimary)),
              const SizedBox(height: 2),
              Text(body,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: colors.textSecondary, height: 1.35)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Section icon button ───────────────────────────────────────────────────────
class _SectionIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final AppColorScheme colors;

  const _SectionIconButton(
      {required this.icon, required this.tooltip, required this.onTap, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.border),
          ),
          child: Icon(icon, size: 16, color: colors.textSecondary),
        ),
      ),
    );
  }
}

// ── Collapsible ingredient list ───────────────────────────────────────────────
class _CollapsibleIngredientList extends StatefulWidget {
  final List<Ingredient> ingredients;
  final AppColorScheme colors;

  /// Resolves an ingredient name to the one it replaced during adaptation.
  final String? Function(String name)? swappedFrom;

  const _CollapsibleIngredientList({
    required this.ingredients,
    required this.colors,
    this.swappedFrom,
  });

  @override
  State<_CollapsibleIngredientList> createState() =>
      _CollapsibleIngredientListState();
}

class _CollapsibleIngredientListState
    extends State<_CollapsibleIngredientList> {
  static const int _collapseThreshold = 10;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final all = widget.ingredients;
    final collapsed = !_expanded && all.length > _collapseThreshold;
    final visible = collapsed ? all.take(_collapseThreshold).toList() : all;

    final list = Column(
      children: visible
          .asMap()
          .entries
          .map((e) => IngredientRow(
                ingredient: e.value,
                index: e.key,
                swappedFrom: widget.swappedFrom?.call(e.value.name),
              ))
          .toList(),
    );

    if (!collapsed) return list;

    // Wrap in a Stack with a bottom blur gradient + "See all" button
    return Stack(
      clipBehavior: Clip.none,
      children: [
        list,
        // Gradient fade
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 100,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    widget.colors.bg.withValues(alpha: 0.0),
                    widget.colors.bg.withValues(alpha: 0.85),
                    widget.colors.bg,
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ),
        ),
        // Down arrow expand button
        Positioned(
          left: 0,
          right: 0,
          bottom: 6,
          child: Center(
            child: GestureDetector(
              onTap: () => setState(() => _expanded = true),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: widget.colors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: widget.colors.border),
                ),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: widget.colors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Step tile ─────────────────────────────────────────────────────────────────
class _StepTile extends StatelessWidget {
  final int number;
  final String text;
  final AppColorScheme colors;

  const _StepTile({required this.number, required this.text, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
                color: AppColors.primary, shape: BoxShape.circle),
            child: Center(
              child: Text('$number',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Text(text,
                  style: AppTextStyles.bodyMedium.copyWith(height: 1.5))),
        ],
      ),
    );
  }
}

// ── Hero placeholder ──────────────────────────────────────────────────────────
class _HeroPlaceholder extends StatelessWidget {
  final AppColorScheme colors;
  const _HeroPlaceholder({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: colors.surface,
      child: Center(child: Icon(Icons.restaurant_menu, size: 64, color: colors.border)),
    );
  }
}

// ── Loading skeleton ──────────────────────────────────────────────────────────
class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Column(
        children: [
          SkeletonLoader(width: double.infinity, height: 300, borderRadius: 0),
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonText(width: 250, height: 28),
                SizedBox(height: 10),
                SkeletonText(width: double.infinity),
                SizedBox(height: 6),
                SkeletonText(width: 200),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Meal plan picker sheet ────────────────────────────────────────────────────
class _MealPlanPickerSheet extends StatefulWidget {
  final Recipe recipe;
  const _MealPlanPickerSheet({required this.recipe});

  @override
  State<_MealPlanPickerSheet> createState() => _MealPlanPickerSheetState();
}

class _MealPlanPickerSheetState extends State<_MealPlanPickerSheet> {
  int _selectedDay = DateTime.now().weekday - 1; // 0=Mon
  String _selectedMeal = 'dinner';
  bool _saving = false;

  final _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final _meals = ['breakfast', 'lunch', 'dinner', 'snack'];

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: colors.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Text('Add to Meal Plan', style: AppTextStyles.headingMedium),
          const SizedBox(height: 4),
          Text(widget.recipe.title,
              style: TextStyle(color: colors.textSecondary, fontSize: 13)),
          const SizedBox(height: 20),
          Text('Day', style: AppTextStyles.labelLarge),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _days.asMap().entries.map((e) {
                final sel = _selectedDay == e.key;
                return GestureDetector(
                  onTap: () => setState(() => _selectedDay = e.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primary : colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: sel ? AppColors.primary : colors.border),
                    ),
                    child: Text(e.value,
                        style: TextStyle(
                            color: sel ? Colors.white : colors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
          Text('Meal', style: AppTextStyles.labelLarge),
          const SizedBox(height: 10),
          Row(
            children: _meals.map((m) {
              final sel = _selectedMeal == m;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedMeal = m),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: EdgeInsets.only(right: m != 'snack' ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primary : colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: sel ? AppColors.primary : colors.border),
                    ),
                    child: Text(
                      m[0].toUpperCase() + m.substring(1),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: sel ? Colors.white : colors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Add to Plan',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final weekday = now.weekday; // 1=Mon
      final weekStart = now.subtract(Duration(days: weekday - 1));
      final targetDate = weekStart.add(Duration(days: _selectedDay));
      final dateKey =
          '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';
      final normalizedWeekStart =
          DateTime(weekStart.year, weekStart.month, weekStart.day);

      final existing =
          await FirebaseService.getMealPlanForWeek(normalizedWeekStart);
      final currentSlots = Map<String, Map<String, MealSlot>>.from(
        (existing?.slots ?? {}).map(
          (k, v) => MapEntry(k, Map<String, MealSlot>.from(v)),
        ),
      );
      currentSlots[dateKey] = {
        ...?currentSlots[dateKey],
        _selectedMeal: MealSlot(
          mealType: _selectedMeal,
          recipeId: widget.recipe.id,
          recipeTitle: widget.recipe.title,
        ),
      };

      await FirebaseService.saveMealPlan(MealPlan(
        id: existing?.id ?? const Uuid().v4(),
        userId: FirebaseService.currentUserId ?? '',
        weekStart: normalizedWeekStart,
        slots: currentSlots,
      ));

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Added to meal plan!'),
              backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ── Tailor sheet ──────────────────────────────────────────────────────────────
class TailorSheet extends StatefulWidget {
  final Recipe recipe;
  final ScrollController? scrollController;
  const TailorSheet({super.key, required this.recipe, this.scrollController});

  @override
  State<TailorSheet> createState() => _TailorSheetState();
}

class _TailorSheetState extends State<TailorSheet> {
  bool _profileLoading = true;
  bool _isLoading = false;
  bool _hasResult = false;
  Map<String, dynamic>? _result;
  String? _error;

  String _dietMode = 'None';
  List<String> _allergies = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await FirebaseService.getProfile();
      if (mounted && profile != null) {
        final allergiesRaw = profile['allergies'];
        setState(() {
          _dietMode = profile['diet_mode'] as String? ?? 'None';
          if (allergiesRaw is List) {
            _allergies = allergiesRaw.map((e) => e.toString()).toList();
          } else if (allergiesRaw is String && allergiesRaw.trim().isNotEmpty) {
            _allergies = allergiesRaw
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();
          }
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _profileLoading = false);
    }
  }

  Future<void> _tailor() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await ClaudeService.tailorRecipe(
        recipe: widget.recipe.toJson(),
        dietMode: _dietMode,
        allergies: _allergies,
      );
      setState(() {
        _result = result;
        _hasResult = true;
      });
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: colors.border, borderRadius: BorderRadius.circular(2)),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: widget.scrollController,
              padding: EdgeInsets.fromLTRB(
                  24, 20, 24, MediaQuery.of(context).padding.bottom + 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.tune_rounded,
                            color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tailor Recipe', style: AppTextStyles.headingMedium),
                          Text('Personalised for you',
                              style: TextStyle(
                                  color: colors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  if (!_hasResult) ...[
                    // ── Option chooser ─────────────────────────────────────
                    if (_isLoading) ...[
                      Text('Tailoring to your preferences...',
                          style: AppTextStyles.labelLarge),
                      const SizedBox(height: 16),
                      _TailorSkeleton(colors: colors),
                    ] else ...[
                      Text(
                        'We can adapt this recipe to fit the preferences from your profile.',
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: colors.textSecondary),
                      ),
                      const SizedBox(height: 20),

                      // Current preference summary card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.restaurant_outlined,
                                    size: 16, color: colors.textSecondary),
                                const SizedBox(width: 8),
                                Text('Diet',
                                    style: TextStyle(
                                        color: colors.textSecondary,
                                        fontSize: 12)),
                                const Spacer(),
                                Text(
                                  _profileLoading ? '…' : _dietMode,
                                  style: TextStyle(
                                      color: colors.textPrimary,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            if (_allergies.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.warning_amber_rounded,
                                      size: 16, color: colors.textSecondary),
                                  const SizedBox(width: 8),
                                  Text('Allergies',
                                      style: TextStyle(
                                          color: colors.textSecondary,
                                          fontSize: 12)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _allergies.join(', '),
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                          color: colors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Use current preferences
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _profileLoading ? null : _tailor,
                          icon: const Icon(Icons.soup_kitchen_rounded, size: 18),
                          label: const Text('Use current preferences'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 52),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Change preferences → profile
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            context.push('/profile');
                          },
                          icon: Icon(Icons.tune_rounded,
                              size: 18, color: colors.textPrimary),
                          label: Text('Change preferences',
                              style: TextStyle(color: colors.textPrimary)),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 52),
                            side: BorderSide(color: colors.border),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(_error ?? 'Something went wrong. Please try again.',
                              style: const TextStyle(color: AppColors.error)),
                        ),
                    ],
                  ] else ...[
                    // ── Results ────────────────────────────────────────────
                    _TailorResults(result: _result!, colors: colors),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => setState(() {
                          _hasResult = false;
                          _result = null;
                        }),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          side: BorderSide(color: colors.border),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text('Adjust preferences',
                            style: TextStyle(color: colors.textPrimary)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 52),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: const Text('Continue with this recipe',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TailorSkeleton extends StatelessWidget {
  final AppColorScheme colors;
  const _TailorSkeleton({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonText(width: 200, height: 16),
        const SizedBox(height: 12),
        ...List.generate(
          3,
          (_) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonText(width: 160),
                SizedBox(height: 8),
                SkeletonText(width: double.infinity),
                SizedBox(height: 4),
                SkeletonText(width: 220),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TailorResults extends StatelessWidget {
  final Map<String, dynamic> result;
  final AppColorScheme colors;

  const _TailorResults({required this.result, required this.colors});

  @override
  Widget build(BuildContext context) {
    final changes = result['changes'] as List? ?? [];
    final assessment = result['overallAssessment'] as String? ?? '';
    final warnings = result['warnings'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Overall assessment
        if (assessment.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(assessment,
                      style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 13,
                          height: 1.5)),
                ),
              ],
            ),
          ).animate().fadeIn().scale(duration: 300.ms),
          const SizedBox(height: 16),
        ],

        // Warnings
        if (warnings.isNotEmpty) ...[
          ...warnings.map((w) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: AppColors.warning, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(w.toString(),
                            style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 12,
                                height: 1.4))),
                  ],
                ),
              )),
          const SizedBox(height: 8),
        ],

        // Changes
        if (changes.isNotEmpty) ...[
          Text('Changes Made', style: AppTextStyles.headingMedium),
          const SizedBox(height: 12),
          ...changes.asMap().entries.map((entry) =>
              _TailorChangeCard(
                  change: entry.value as Map<String, dynamic>,
                  index: entry.key,
                  colors: colors)),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Great news — this recipe already fits your profile perfectly!',
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
        ],
      ],
    );
  }
}

class _TailorChangeCard extends StatelessWidget {
  final Map<String, dynamic> change;
  final int index;
  final AppColorScheme colors;

  const _TailorChangeCard(
      {required this.change, required this.index, required this.colors});

  @override
  Widget build(BuildContext context) {
    final confidence = change['confidence'] as String? ?? 'medium';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Original → Replacement
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: colors.bg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: colors.border),
                  ),
                  child: Text(
                    change['original'] as String? ?? '',
                    style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12,
                        decoration: TextDecoration.lineThrough,
                        fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward, size: 14, color: colors.textSecondary),
              ),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    change['replacement'] as String? ?? '',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Confidence badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  confidence,
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Reason
          Text(change['reason'] as String? ?? '',
              style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          // Culinary sense
          if ((change['culinarySense'] as String?)?.isNotEmpty == true)
            _InfoRow(
              icon: Icons.restaurant_outlined,
              text: change['culinarySense'] as String,
              color: AppColors.success,
            ),
          // Outcome impact
          if ((change['outcomeImpact'] as String?)?.isNotEmpty == true)
            _InfoRow(
              icon: Icons.bubble_chart_outlined,
              text: change['outcomeImpact'] as String,
              color: AppColors.warning,
            ),
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: 80 * index));
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoRow({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.4)),
          ),
        ],
      ),
    );
  }
}

// ── Full-screen cooking mode ──────────────────────────────────────────────────
class CookingModeScreen extends StatefulWidget {
  final List<String> steps;
  final String title;
  final List<Ingredient> ingredients;

  const CookingModeScreen({
    super.key,
    required this.steps,
    required this.title,
    this.ingredients = const [],
  });

  @override
  State<CookingModeScreen> createState() => _CookingModeScreenState();
}

class _CookingModeScreenState extends State<CookingModeScreen> {
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    // Keep the screen awake while cooking so it never dims or locks mid-recipe.
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_currentStep];
    final isFirst = _currentStep == 0;
    final isLast = _currentStep == widget.steps.length - 1;

    return Scaffold(
      backgroundColor: AppColors.cardDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.close, color: Colors.white, size: 20),
                    ),
                  ),
                  Text('Step ${_currentStep + 1} of ${widget.steps.length}',
                      style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(width: 40),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_currentStep + 1) / widget.steps.length,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  minHeight: 4,
                ),
              ),
              const Spacer(),
              Container(
                width: 56, height: 56,
                decoration: const BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle),
                child: Center(
                  child: Text('${_currentStep + 1}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800)),
                ),
              ).animate().scale(duration: 300.ms, curve: Curves.elasticOut),
              const SizedBox(height: 28),
              // Step text with ingredient annotations
              _AnnotatedStepText(
                key: ValueKey(_currentStep),
                stepText: step,
                ingredients: widget.ingredients,
              ),
              const Spacer(),
              Row(
                children: [
                  if (!isFirst) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _currentStep--),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 56),
                          side: const BorderSide(color: Colors.white30, width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Previous'),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: isLast
                          ? () => Navigator.of(context).pop()
                          : () => setState(() => _currentStep++),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 56),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: Text(isLast ? '🎉 Done!' : 'Next Step',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Annotated step text with tappable ingredient hints ────────────────────────
class _AnnotatedStepText extends StatefulWidget {
  final String stepText;
  final List<Ingredient> ingredients;

  const _AnnotatedStepText({
    super.key,
    required this.stepText,
    required this.ingredients,
  });

  @override
  State<_AnnotatedStepText> createState() => _AnnotatedStepTextState();
}

class _AnnotatedStepTextState extends State<_AnnotatedStepText> {
  OverlayEntry? _overlay;

  void _showTooltip(BuildContext context, String label, Offset globalPos) {
    _dismissTooltip();
    _overlay = OverlayEntry(
      builder: (_) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _dismissTooltip,
        child: Stack(
          children: [
            Positioned(
              // Position the tooltip just above the tap point
              left: (globalPos.dx - 80).clamp(8.0, double.infinity),
              top: globalPos.dy - 56,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    Overlay.of(context).insert(_overlay!);
  }

  void _dismissTooltip() {
    _overlay?.remove();
    _overlay = null;
  }

  @override
  void dispose() {
    _dismissTooltip();
    super.dispose();
  }

  /// Builds a list of InlineSpan segments from the step text,
  /// highlighting any ingredient name found in the text.
  List<InlineSpan> _buildSpans(BuildContext context) {
    if (widget.ingredients.isEmpty) {
      return [TextSpan(text: widget.stepText)];
    }

    // Sort by name length descending so longer names match first
    final sorted = [...widget.ingredients]
      ..sort((a, b) => b.name.length.compareTo(a.name.length));

    // Build a regex that matches any ingredient name (case-insensitive)
    final pattern = sorted
        .map((i) => RegExp.escape(i.name.toLowerCase()))
        .join('|');
    final regex = RegExp(pattern, caseSensitive: false);

    final spans = <InlineSpan>[];
    int cursor = 0;
    final text = widget.stepText;

    for (final match in regex.allMatches(text)) {
      // Plain text before this match
      if (match.start > cursor) {
        spans.add(TextSpan(
          text: text.substring(cursor, match.start),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w400,
            height: 1.6,
          ),
        ));
      }

      // Find matching ingredient to get amount
      final matchedName = match.group(0)!.toLowerCase();
      final ingredient = sorted.firstWhere(
        (i) => i.name.toLowerCase() == matchedName,
        orElse: () => sorted.first,
      );
      final amount = ingredient.amount == ingredient.amount.roundToDouble()
          ? ingredient.amount.round().toString()
          : ingredient.amount.toStringAsFixed(1);
      final amountLabel =
          '$amount${ingredient.unit.isNotEmpty ? ' ${ingredient.unit}' : ''}';

      // Tappable highlighted span
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: GestureDetector(
          onTapDown: (details) => _showTooltip(
            context,
            '${text.substring(match.start, match.end)} · $amountLabel',
            details.globalPosition,
          ),
          child: Text(
            text.substring(match.start, match.end),
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 22,
              fontWeight: FontWeight.w600,
              height: 1.6,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.accent,
              decorationThickness: 3.0,
            ),
          ),
        ),
      ));


      cursor = match.end;
    }

    // Remaining plain text
    if (cursor < text.length) {
      spans.add(TextSpan(
        text: text.substring(cursor),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w400,
          height: 1.6,
        ),
      ));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: _buildSpans(context)),
    )
        .animate(key: widget.key)
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.05, end: 0);
  }
}

// ── Add to Collection sheet ───────────────────────────────────────────────────
class _AddToCollectionSheet extends StatefulWidget {
  final String recipeId;
  const _AddToCollectionSheet({required this.recipeId});

  @override
  State<_AddToCollectionSheet> createState() => _AddToCollectionSheetState();
}

class _AddToCollectionSheetState extends State<_AddToCollectionSheet> {
  List<Collection>? _collections;
  Set<String> _alreadyIn = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final collections = await FirebaseService.getCollections();
    final ids = await FirebaseService.getRecipeCollectionIds(widget.recipeId);
    if (mounted) {
      setState(() {
        _collections = collections;
        _alreadyIn = ids.toSet();
        _loading = false;
      });
    }
  }

  Future<void> _toggle(Collection col) async {
    final inCollection = _alreadyIn.contains(col.id);
    setState(() {
      if (inCollection) {
        _alreadyIn.remove(col.id);
      } else {
        _alreadyIn.add(col.id);
      }
    });
    try {
      if (inCollection) {
        await FirebaseService.removeRecipeFromCollection(col.id, widget.recipeId);
      } else {
        await FirebaseService.addRecipeToCollection(col.id, widget.recipeId);
      }
    } catch (e) {
      // revert on error
      setState(() {
        if (inCollection) _alreadyIn.add(col.id);
        else _alreadyIn.remove(col.id);
      });
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _createAndAdd() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New Collection'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Collection name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await FirebaseService.createCollection(name);
    await _load();
    // Auto-add to the new collection
    final newCol = _collections?.firstWhere((c) => c.name == name,
        orElse: () => _collections!.last);
    if (newCol != null) await _toggle(newCol);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Save to Collection', style: AppTextStyles.headingMedium),
              TextButton.icon(
                onPressed: _createAndAdd,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
            )
          else if (_collections == null || _collections!.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No collections yet. Tap "New" to create one.',
                  style: TextStyle(color: colors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _collections!.length,
                separatorBuilder: (_, __) => Divider(color: colors.border, height: 1),
                itemBuilder: (_, i) {
                  final col = _collections![i];
                  final checked = _alreadyIn.contains(col.id);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: checked
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : colors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.border),
                      ),
                      child: Icon(
                        Icons.collections_bookmark_outlined,
                        color: checked ? AppColors.primary : colors.textSecondary,
                        size: 18,
                      ),
                    ),
                    title: Text(col.name,
                        style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600)),
                    trailing: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                        color: checked ? AppColors.primary : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: checked ? AppColors.primary : colors.border,
                          width: 1.5,
                        ),
                      ),
                      child: checked
                          ? const Icon(Icons.check, color: Colors.white, size: 14)
                          : null,
                    ),
                    onTap: () => _toggle(col),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
