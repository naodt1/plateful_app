import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/providers/recipe_providers.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/claude_service.dart';
import '../../../core/widgets/airbnb_button.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../models/recipe.dart';
import '../../../models/meal_plan.dart';
import '../../subscription/pro_gate.dart';

// Full-page screen kept for deep-link / share-sheet entry
class AddRecipeScreen extends StatelessWidget {
  final String? prefillUrl;
  const AddRecipeScreen({super.key, this.prefillUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(context).bg,
      body: AddRecipeSheet(prefillUrl: prefillUrl),
    );
  }
}

// Bottom-sheet widget — also used standalone inside a Scaffold above
class AddRecipeSheet extends ConsumerStatefulWidget {
  final String? prefillUrl;
  final ScrollController? scrollController;
  final Recipe? existingRecipe;

  const AddRecipeSheet({
    super.key,
    this.prefillUrl,
    this.scrollController,
    this.existingRecipe,
  });

  @override
  ConsumerState<AddRecipeSheet> createState() => _AddRecipeSheetState();
}

class _AddRecipeSheetState extends ConsumerState<AddRecipeSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _urlController = TextEditingController();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _ingredientController = TextEditingController();
  final _stepController = TextEditingController();

  final List<String> _ingredients = [];
  final List<String> _steps = [];

  bool _isExtracting = false;
  bool _isSaving = false;
  Map<String, dynamic>? _extractedRecipe;

  bool get _isEditing => widget.existingRecipe != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.prefillUrl != null) {
      _urlController.text = widget.prefillUrl!;
    }
    final existing = widget.existingRecipe;
    if (existing != null) {
      // Pre-fill the manual-entry form with the recipe being edited.
      _titleController.text = existing.title;
      _descController.text = existing.description;
      for (final ing in existing.ingredients) {
        final amt = ing.amount == ing.amount.roundToDouble()
            ? ing.amount.round().toString()
            : ing.amount.toString();
        _ingredients.add('$amt ${ing.unit} ${ing.name}'.trim());
      }
      _steps.addAll(existing.steps);
      _extractedRecipe = existing.toJson();
      // Jump straight to the editable form.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _tabController.animateTo(1);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    _titleController.dispose();
    _descController.dispose();
    _ingredientController.dispose();
    _stepController.dispose();
    super.dispose();
  }

  Future<void> _extractRecipe() async {
    if (_urlController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please enter a URL')));
      return;
    }
    // AI extraction counts as an import — free users are limited.
    if (!await ProGate.allowImport(context)) return;
    if (!mounted) return;
    setState(() => _isExtracting = true);
    try {
      final recipe =
          await ClaudeService.extractRecipeFromUrl(_urlController.text.trim());
      await ProGate.recordImport();
      setState(() {
        _extractedRecipe = recipe;
        _titleController.text = recipe['title'] as String? ?? '';
        _descController.text = recipe['description'] as String? ?? '';
        final ingList = recipe['ingredients'] as List? ?? [];
        _ingredients.clear();
        for (final ing in ingList) {
          final map = ing as Map<String, dynamic>;
          final amount = map['amount'];
          final unit = map['unit'] as String? ?? '';
          final name = map['name'] as String? ?? '';
          _ingredients.add('$amount $unit $name'.trim());
        }
        final stepsList = recipe['steps'] as List? ?? [];
        _steps.clear();
        _steps.addAll(stepsList.map((e) => e.toString()));
      });
      _tabController.animateTo(1);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExtracting = false);
    }
  }

  Future<void> _saveRecipe() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a recipe title')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final userId = SupabaseService.currentUser?.id ?? '';
      final ingredients = _ingredients.map((s) {
        final parts = s.trim().split(' ');
        final amount =
            double.tryParse(parts.isNotEmpty ? parts[0] : '1') ?? 1;
        final unit = parts.length > 1 ? parts[1] : '';
        final name =
            parts.length > 2 ? parts.sublist(2).join(' ') : s;
        return Ingredient(name: name, amount: amount, unit: unit);
      }).toList();

      final nutritionRaw = _extractedRecipe?['nutrition'];
      Nutrition? nutrition;
      if (nutritionRaw is Map<String, dynamic>) {
        nutrition = Nutrition.fromJson(nutritionRaw);
      }

      final tagsRaw = _extractedRecipe?['tags'] as List?;
      final imageUrl = _extractedRecipe?['image_url'] as String?;
      final existing = widget.existingRecipe;

      final recipe = Recipe(
        id: existing?.id ?? const Uuid().v4(),
        userId: existing?.userId ?? userId,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        imageUrl: imageUrl,
        sourceUrl: existing?.sourceUrl ??
            (_urlController.text.trim().isNotEmpty
                ? _urlController.text.trim()
                : null),
        sourceType: existing?.sourceType ??
            (_urlController.text.trim().isNotEmpty ? 'link' : 'manual'),
        ingredients: ingredients,
        steps: List<String>.from(_steps),
        nutrition: nutrition,
        tags: tagsRaw?.map((e) => e.toString()).toList() ?? [],
        createdAt: existing?.createdAt ?? DateTime.now(),
        servings: (_extractedRecipe?['servings'] as num?)?.toInt() ?? 4,
      );

      if (_isEditing) {
        await SupabaseService.updateRecipe(recipe);
        refreshRecipeData(ref); // refresh home screen
        if (mounted) {
          Navigator.of(context).pop(true); // signal "changed" to caller
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recipe updated')),
          );
        }
      } else {
        final recipeId = await SupabaseService.saveRecipe(recipe);
        final savedRecipe = recipe.copyWith(id: recipeId);
        refreshRecipeData(ref); // refresh home screen
        if (mounted) {
          Navigator.of(context).pop();
          await _showAddToMealPlanSheet(savedRecipe);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _showAddToMealPlanSheet(Recipe recipe) async {
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddToMealPlanSheet(recipe: recipe),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.of(context).bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.of(context).border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_isEditing ? 'Edit Recipe' : 'Add Recipe',
                    style: AppTextStyles.headingMedium),
                Row(
                  children: [
                    TextButton(
                      onPressed: _isSaving ? null : _saveRecipe,
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary),
                            )
                          : const Text(
                              'Save',
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15),
                            ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Tab bar
          TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.of(context).textSecondary,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(text: 'Paste Link'),
              Tab(text: 'Manual Entry'),
            ],
          ),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _PasteLinkTab(
                  controller: _urlController,
                  isExtracting: _isExtracting,
                  onExtract: _extractRecipe,
                ),
                _ManualEntryTab(
                  titleController: _titleController,
                  descController: _descController,
                  ingredientController: _ingredientController,
                  stepController: _stepController,
                  ingredients: _ingredients,
                  steps: _steps,
                  onAddIngredient: () {
                    final text = _ingredientController.text.trim();
                    if (text.isNotEmpty) {
                      setState(() {
                        _ingredients.add(text);
                        _ingredientController.clear();
                      });
                    }
                  },
                  onRemoveIngredient: (i) =>
                      setState(() => _ingredients.removeAt(i)),
                  onAddStep: () {
                    final text = _stepController.text.trim();
                    if (text.isNotEmpty) {
                      setState(() {
                        _steps.add(text);
                        _stepController.clear();
                      });
                    }
                  },
                  onRemoveStep: (i) => setState(() => _steps.removeAt(i)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PasteLinkTab extends StatelessWidget {
  final TextEditingController controller;
  final bool isExtracting;
  final VoidCallback onExtract;

  const _PasteLinkTab({
    required this.controller,
    required this.isExtracting,
    required this.onExtract,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.of(context).surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Paste any recipe URL and AI will extract the details.',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.of(context).textPrimary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: controller,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              hintText: 'https://recipe-website.com/pasta',
              prefixIcon:
                  Icon(Icons.link, color: AppColors.of(context).textSecondary),
              suffixIcon: isExtracting
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary),
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          if (isExtracting)
            _ExtractionSkeleton()
          else
            AirbnbButton(
              label: 'Extract Recipe with AI',
              onPressed: onExtract,
              icon: Icons.auto_awesome,
            ),
        ],
      ),
    );
  }
}

class _ExtractionSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Center(
          child: Text('Extracting recipe with AI...',
              style: TextStyle(color: AppColors.of(context).textSecondary)),
        ),
        const SizedBox(height: 16),
        const SkeletonText(width: 200, height: 20),
        const SizedBox(height: 12),
        const SkeletonText(width: double.infinity),
        const SizedBox(height: 6),
        const SkeletonText(width: double.infinity),
        const SizedBox(height: 6),
        const SkeletonText(width: 240),
        const SizedBox(height: 20),
        const SkeletonText(width: 120, height: 16),
        const SizedBox(height: 10),
        ...List.generate(
            4,
            (_) => const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: SkeletonText(width: double.infinity),
                )),
      ],
    );
  }
}

class _ManualEntryTab extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController descController;
  final TextEditingController ingredientController;
  final TextEditingController stepController;
  final List<String> ingredients;
  final List<String> steps;
  final VoidCallback onAddIngredient;
  final void Function(int) onRemoveIngredient;
  final VoidCallback onAddStep;
  final void Function(int) onRemoveStep;

  const _ManualEntryTab({
    required this.titleController,
    required this.descController,
    required this.ingredientController,
    required this.stepController,
    required this.ingredients,
    required this.steps,
    required this.onAddIngredient,
    required this.onRemoveIngredient,
    required this.onAddStep,
    required this.onRemoveStep,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('Recipe Title'),
          const SizedBox(height: 8),
          TextField(
            controller: titleController,
            decoration:
                const InputDecoration(hintText: 'e.g. Spaghetti Carbonara'),
          ),
          const SizedBox(height: 16),
          _SectionLabel('Description'),
          const SizedBox(height: 8),
          TextField(
            controller: descController,
            maxLines: 3,
            decoration: const InputDecoration(
                hintText: 'Brief description of the recipe...'),
          ),
          const SizedBox(height: 24),
          _SectionLabel('Ingredients'),
          const SizedBox(height: 8),
          ...ingredients.asMap().entries.map((e) => _ItemTile(
                index: e.key,
                text: e.value,
                onRemove: () => onRemoveIngredient(e.key),
                bullet: '•',
              )),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: ingredientController,
                  decoration: InputDecoration(
                    hintText: '2 cups flour',
                    prefixIcon:
                        Icon(Icons.add, color: AppColors.of(context).textSecondary),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onAddIngredient,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionLabel('Steps'),
          const SizedBox(height: 8),
          ...steps.asMap().entries.map((e) => _ItemTile(
                index: e.key,
                text: e.value,
                onRemove: () => onRemoveStep(e.key),
                bullet: '${e.key + 1}.',
              )),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: stepController,
                  maxLines: 2,
                  decoration:
                      const InputDecoration(hintText: 'Add a step...'),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onAddStep,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: AppTextStyles.labelLarge.copyWith(fontSize: 15));
  }
}

class _ItemTile extends StatelessWidget {
  final int index;
  final String text;
  final VoidCallback onRemove;
  final String bullet;

  const _ItemTile({
    required this.index,
    required this.text,
    required this.onRemove,
    required this.bullet,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.of(context).border),
      ),
      child: Row(
        children: [
          Text(
            bullet,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: AppTextStyles.bodyMedium)),
          IconButton(
            icon: Icon(Icons.remove_circle_outline,
                color: AppColors.of(context).textSecondary, size: 18),
            onPressed: onRemove,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ─── Add to Meal Plan Sheet ────────────────────────────────────────────────

DateTime _weekStartOf(DateTime date) {
  final weekday = date.weekday;
  return DateTime(date.year, date.month, date.day - (weekday - 1));
}

class _AddToMealPlanSheet extends StatefulWidget {
  final Recipe recipe;
  const _AddToMealPlanSheet({required this.recipe});

  @override
  State<_AddToMealPlanSheet> createState() => _AddToMealPlanSheetState();
}

class _AddToMealPlanSheetState extends State<_AddToMealPlanSheet> {
  DateTime _selectedDate = DateTime.now();
  String _selectedMealType = 'dinner';
  bool _isSaving = false;

  static const _mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];

  List<DateTime> get _weekDays {
    final weekStart = _weekStartOf(_selectedDate);
    return List.generate(7, (i) => weekStart.add(Duration(days: i)));
  }

  Future<void> _addToPlan() async {
    setState(() => _isSaving = true);
    try {
      final weekStart = _weekStartOf(_selectedDate);
      final dateKey = _selectedDate.toIso8601String().split('T').first;

      final existing = await SupabaseService.getMealPlanForWeek(weekStart);

      final slotsMap = Map<String, Map<String, MealSlot>>.from(
        (existing?.slots ?? {}).map(
          (k, v) => MapEntry(k, Map<String, MealSlot>.from(v)),
        ),
      );
      slotsMap.putIfAbsent(dateKey, () => {});
      slotsMap[dateKey]![_selectedMealType] = MealSlot(
        mealType: _selectedMealType,
        recipeId: widget.recipe.id,
        recipeTitle: widget.recipe.title,
      );

      final plan = MealPlan(
        id: existing?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        userId: SupabaseService.currentUser?.id ?? '',
        weekStart: weekStart,
        slots: slotsMap,
      );

      await SupabaseService.saveMealPlan(plan);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Added to ${_selectedMealType[0].toUpperCase()}${_selectedMealType.substring(1)} on ${DateFormat('EEE, MMM d').format(_selectedDate)}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final days = _weekDays;
    final today = DateTime.now();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Add to Meal Plan?', style: AppTextStyles.headingMedium),
          const SizedBox(height: 6),
          Text(
            widget.recipe.title,
            style: AppTextStyles.bodyMedium
                .copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 20),

          // Day picker
          Text('Select Day',
              style: AppTextStyles.labelLarge
                  .copyWith(color: colors.textSecondary)),
          const SizedBox(height: 10),
          SizedBox(
            height: 64,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: days.length,
              itemBuilder: (ctx, i) {
                final day = days[i];
                final isToday = day.year == today.year &&
                    day.month == today.month &&
                    day.day == today.day;
                final isSelected = day.year == _selectedDate.year &&
                    day.month == _selectedDate.month &&
                    day.day == _selectedDate.day;
                return GestureDetector(
                  onTap: () => setState(() => _selectedDate = day),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 52,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : colors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : isToday
                                ? AppColors.primary.withOpacity(0.4)
                                : colors.border,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('E').format(day),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // Meal type picker
          Text('Meal',
              style: AppTextStyles.labelLarge
                  .copyWith(color: colors.textSecondary)),
          const SizedBox(height: 10),
          Row(
            children: _mealTypes.map((type) {
              final isSelected = type == _selectedMealType;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedMealType = type),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: isSelected ? AppColors.primary : colors.border),
                    ),
                    child: Text(
                      type[0].toUpperCase() + type.substring(1),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color:
                            isSelected ? Colors.white : colors.textPrimary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: colors.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size(0, 48),
                  ),
                  child: Text('Skip',
                      style: TextStyle(color: colors.textSecondary)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _addToPlan,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Add to Plan'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
