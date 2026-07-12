import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/claude_service.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../models/meal_plan.dart';
import '../../../models/recipe.dart';
import '../widgets/week_calendar.dart';
import '../widgets/meal_slot_card.dart';
import '../../subscription/pro_gate.dart';
import '../../../core/utils/error_messages.dart';

DateTime _getWeekStart(DateTime date) {
  final weekday = date.weekday;
  return DateTime(date.year, date.month, date.day - (weekday - 1));
}

final _mealPlanProvider =
    FutureProvider.family<MealPlan?, DateTime>((ref, weekStart) {
  return FirebaseService.getMealPlanForWeek(weekStart);
});

final _savedRecipesProvider = FutureProvider<List<Recipe>>((ref) {
  return FirebaseService.getRecipes();
});

class MealPlanScreen extends ConsumerStatefulWidget {
  const MealPlanScreen({super.key});

  @override
  ConsumerState<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends ConsumerState<MealPlanScreen> {
  DateTime _selectedDate = DateTime.now();
  late DateTime _weekStart;
  bool _isGenerating = false;

  // Local overlay to hold changes before persisting
  MealPlan? _localPlan;

  @override
  void initState() {
    super.initState();
    _weekStart = _getWeekStart(DateTime.now());
    _selectedDate = _weekStart;
  }

  Future<void> _generatePlan() async {
    // AI meal-plan generation is a Pro feature.
    if (!await ProGate.ensurePro(context)) return;
    if (!mounted) return;
    setState(() => _isGenerating = true);
    try {
      final profile = await FirebaseService.getProfile();
      final dietMode = profile?['diet_mode'] as String? ?? 'None';
      final plan = await ClaudeService.generateMealPlan(dietMode);

      final slotsMap = <String, Map<String, MealSlot>>{};
      final dayNames = [
        'monday',
        'tuesday',
        'wednesday',
        'thursday',
        'friday',
        'saturday',
        'sunday'
      ];

      for (int i = 0; i < 7; i++) {
        final date = _weekStart.add(Duration(days: i));
        final dateKey = date.toIso8601String().split('T').first;
        final dayData =
            plan[dayNames[i]] as Map<String, dynamic>? ?? {};

        final daySlots = <String, MealSlot>{};
        for (final mealType in [
          'breakfast',
          'lunch',
          'dinner',
          'snack'
        ]) {
          final mealData =
              dayData[mealType] as Map<String, dynamic>?;
          if (mealData != null) {
            daySlots[mealType] = MealSlot(
              mealType: mealType,
              recipeTitle: mealData['title'] as String?,
            );
          }
        }
        slotsMap[dateKey] = daySlots;
      }

      final mealPlan = MealPlan(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: FirebaseService.currentUserId ?? '',
        weekStart: _weekStart,
        slots: slotsMap,
      );

      await FirebaseService.saveMealPlan(mealPlan);
      setState(() => _localPlan = mealPlan);
      ref.invalidate(_mealPlanProvider(_weekStart));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _pickRecipe(MealPlan? currentPlan, String dateKey,
      String mealType, List<Recipe> recipes) async {
    final result = await showModalBottomSheet<Recipe>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RecipePickerSheet(recipes: recipes),
    );

    if (result == null) return;

    // Merge into plan
    final currentSlots = Map<String, Map<String, MealSlot>>.from(
      (currentPlan?.slots ?? {}).map(
        (k, v) => MapEntry(k, Map<String, MealSlot>.from(v)),
      ),
    );
    currentSlots.putIfAbsent(dateKey, () => {});
    currentSlots[dateKey]![mealType] = MealSlot(
      mealType: mealType,
      recipeId: result.id,
      recipeTitle: result.title,
      recipeImage: result.imageUrl,
    );

    final updated = MealPlan(
      id: currentPlan?.id ?? '',
      userId: FirebaseService.currentUserId ?? '',
      weekStart: _weekStart,
      slots: currentSlots,
    );

    // Optimistic update so the UI reflects the change immediately.
    setState(() => _localPlan = updated);
    try {
      await FirebaseService.saveMealPlan(updated);
      ref.invalidate(_mealPlanProvider(_weekStart));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e))),
        );
      }
    }
  }

  Future<void> _removeSlot(MealPlan plan, String dateKey,
      String mealType) async {
    final currentSlots =
        Map<String, Map<String, MealSlot>>.from(
      plan.slots.map(
        (k, v) => MapEntry(k, Map<String, MealSlot>.from(v)),
      ),
    );
    currentSlots[dateKey]?.remove(mealType);

    final updated = MealPlan(
      id: plan.id,
      userId: plan.userId,
      weekStart: _weekStart,
      slots: currentSlots,
    );
    await FirebaseService.saveMealPlan(updated);
    setState(() => _localPlan = updated);
    ref.invalidate(_mealPlanProvider(_weekStart));
  }

  void _showSlotOptions(MealPlan plan, String dateKey, String mealType,
      MealSlot? slot, List<Recipe> recipes) {
    if (slot?.recipeTitle != null) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          final colors = AppColors.of(ctx);
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colors.bg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(slot!.recipeTitle!,
                    style: AppTextStyles.headingMedium),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.swap_horiz,
                      color: AppColors.primary),
                  title: const Text('Change Recipe'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickRecipe(plan, dateKey, mealType, recipes);
                  },
                ),
                ListTile(
                  leading:
                      const Icon(Icons.delete_outline, color: AppColors.error),
                  title: const Text('Remove',
                      style: TextStyle(color: AppColors.error)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _removeSlot(plan, dateKey, mealType);
                  },
                ),
              ],
            ),
          );
        },
      );
    } else {
      _pickRecipe(plan, dateKey, mealType, recipes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final mealPlanAsync = ref.watch(_mealPlanProvider(_weekStart));
    final recipesAsync = ref.watch(_savedRecipesProvider);
    final selectedDateKey =
        _selectedDate.toIso8601String().split('T').first;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        title: Text('Meal Plan', style: AppTextStyles.headingMedium),
        automaticallyImplyLeading: false,
        backgroundColor: colors.bg,
        actions: [
          TextButton(
            onPressed: _isGenerating ? null : _generatePlan,
            child: _isGenerating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  )
                : const Text('Generate Week',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Week navigator
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left,
                      color: colors.textPrimary),
                  onPressed: () => setState(() {
                    _weekStart =
                        _weekStart.subtract(const Duration(days: 7));
                    _selectedDate = _weekStart;
                    _localPlan = null;
                  }),
                ),
                Text(
                  '${DateFormat('MMM d').format(_weekStart)} — '
                  '${DateFormat('MMM d, y').format(_weekStart.add(const Duration(days: 6)))}',
                  style: AppTextStyles.labelLarge,
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right,
                      color: colors.textPrimary),
                  onPressed: () => setState(() {
                    _weekStart =
                        _weekStart.add(const Duration(days: 7));
                    _selectedDate = _weekStart;
                    _localPlan = null;
                  }),
                ),
              ],
            ),
          ),

          WeekCalendar(
            selectedDate: _selectedDate,
            weekStart: _weekStart,
            onDaySelected: (date) =>
                setState(() => _selectedDate = date),
          ),

          const SizedBox(height: 12),

          Expanded(
            child: mealPlanAsync.when(
              data: (fetchedPlan) {
                final plan = _localPlan ?? fetchedPlan;
                final daySlots = plan?.slots[selectedDateKey] ?? {};
                final recipes = recipesAsync.value ?? [];

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Text(
                      DateFormat('EEEE, MMMM d').format(_selectedDate),
                      style: AppTextStyles.headingMedium,
                    ),
                    const SizedBox(height: 12),
                    for (final mealType in [
                      'breakfast',
                      'lunch',
                      'dinner',
                      'snack'
                    ])
                      MealSlotCard(
                        mealType: mealType,
                        slot: daySlots[mealType],
                        onTap: () => _showSlotOptions(
                          plan ??
                              MealPlan(
                                id: '',
                                userId:
                                    FirebaseService.currentUserId ??
                                        '',
                                weekStart: _weekStart,
                                slots: {},
                              ),
                          selectedDateKey,
                          mealType,
                          daySlots[mealType],
                          recipes,
                        ),
                      ),
                    const SizedBox(height: 16),
                    if (plan == null)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colors.border),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.auto_awesome,
                                size: 36, color: AppColors.primary),
                            const SizedBox(height: 12),
                            Text('No plan for this week',
                                style: AppTextStyles.headingMedium),
                            const SizedBox(height: 6),
                            Text(
                              'Tap "Generate Week" to create an AI meal plan, or tap any slot to add a recipe.',
                              style: AppTextStyles.bodyMedium.copyWith(
                                  color: colors.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
              loading: () => ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 5,
                itemBuilder: (_, __) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: const SkeletonLoader(
                      width: double.infinity,
                      height: 64,
                      borderRadius: 16),
                ),
              ),
              error: (e, _) => Center(
                child: Text('Couldn\'t load your meal plan.',
                    style: AppTextStyles.bodySmall),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipePickerSheet extends StatelessWidget {
  final List<Recipe> recipes;

  const _RecipePickerSheet({required this.recipes});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text('Pick a Recipe',
                style: AppTextStyles.headingMedium),
          ),
          if (recipes.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No saved recipes. Save recipes first to add them to your meal plan.',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: colors.textSecondary),
                textAlign: TextAlign.center,
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16),
                shrinkWrap: true,
                itemCount: recipes.length,
                itemBuilder: (ctx, i) {
                  final recipe = recipes[i];
                  final hasImage =
                      recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty;
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: hasImage
                            ? Image.network(
                                recipe.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  child: const Icon(Icons.restaurant,
                                      color: AppColors.primary, size: 18),
                                ),
                              )
                            : Container(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                child: const Icon(Icons.restaurant,
                                    color: AppColors.primary, size: 18),
                              ),
                      ),
                    ),
                    title: Text(recipe.title,
                        style: AppTextStyles.labelLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    subtitle: recipe.description.isNotEmpty
                        ? Text(
                            recipe.description,
                            style: AppTextStyles.bodySmall
                                .copyWith(color: colors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : null,
                    onTap: () => Navigator.pop(ctx, recipe),
                  );
                },
              ),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
