import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../models/pantry_item.dart';
import '../widgets/pantry_suggestions_sheet.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/widgets/intelligence_mark.dart';

final _pantryProvider =
    FutureProvider.autoDispose<List<PantryItem>>((ref) {
  return FirebaseService.getPantryItems();
});

// Category → emoji map
String _categoryEmoji(String category) {
  switch (category) {
    case 'Produce':
      return '🥦';
    case 'Dairy':
      return '🥛';
    case 'Meat':
      return '🥩';
    case 'Grains':
      return '🌾';
    case 'Spices':
      return '🧂';
    case 'Oils':
      return '🫙';
    case 'Pantry Staples':
      return '🥫';
    case 'Frozen':
      return '🧊';
    case 'Beverages':
      return '🧃';
    default:
      return '📦';
  }
}

class PantryScreen extends ConsumerStatefulWidget {
  const PantryScreen({super.key});

  @override
  ConsumerState<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends ConsumerState<PantryScreen> {
  String _selectedCategory = 'All';

  static const _filterCategories = [
    'All',
    'Produce',
    'Dairy',
    'Meat',
    'Grains',
    'Spices',
    'Oils',
    'Pantry Staples',
    'Other',
  ];

  static const _addCategories = [
    'Produce',
    'Dairy',
    'Meat',
    'Grains',
    'Spices',
    'Oils',
    'Pantry Staples',
    'Other',
  ];

  Future<void> _deleteItem(String id) async {
    await FirebaseService.deletePantryItem(id);
    ref.invalidate(_pantryProvider);
  }

  void _showSuggestions(List<PantryItem> items) {
    final names = items.map((e) => e.name).toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, __) => PantrySuggestionsSheet(
          pantryItems: names,
        ),
      ),
    );
  }

  void _showAddSheet() {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    String selectedCat = 'Produce';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final colors = AppColors.of(ctx);
            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colors.bg,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
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
                    Text('Add Ingredient',
                        style: AppTextStyles.headingMedium),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      decoration:
                          const InputDecoration(hintText: 'Ingredient name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: qtyCtrl,
                      decoration: const InputDecoration(
                          hintText: 'Quantity (e.g. 2 cups)'),
                    ),
                    const SizedBox(height: 16),
                    Text('Category',
                        style: AppTextStyles.labelLarge
                            .copyWith(color: colors.textSecondary)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _addCategories.map((cat) {
                        final isSel = cat == selectedCat;
                        return GestureDetector(
                          onTap: () =>
                              setSheetState(() => selectedCat = cat),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? AppColors.primary
                                  : colors.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSel
                                    ? AppColors.primary
                                    : colors.border,
                              ),
                            ),
                            child: Text(
                              '${_categoryEmoji(cat)} $cat',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isSel
                                    ? Colors.white
                                    : colors.textPrimary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) return;
                          final userId =
                              FirebaseService.currentUserId ?? '';
                          final item = PantryItem(
                            id: const Uuid().v4(),
                            userId: userId,
                            name: name,
                            category: selectedCat,
                            quantity: qtyCtrl.text.trim(),
                            addedAt: DateTime.now(),
                          );
                          await FirebaseService.addPantryItem(item);
                          ref.invalidate(_pantryProvider);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: const Text('Add to Pantry'),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final pantryAsync = ref.watch(_pantryProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        title: Text('My Pantry', style: AppTextStyles.headingMedium),
        automaticallyImplyLeading: false,
        backgroundColor: colors.bg,
      ),
      body: Column(
        children: [
          // Category filter chips
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filterCategories.length,
              itemBuilder: (context, index) {
                final cat = _filterCategories[index];
                final isSelected = cat == _selectedCategory;
                return GestureDetector(
                  onTap: () =>
                      setState(() => _selectedCategory = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : colors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : colors.border,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          Expanded(
            child: pantryAsync.when(
              data: (items) {
                final filtered = items.where((item) {
                  return _selectedCategory == 'All' ||
                      item.category == _selectedCategory;
                }).toList();

                if (items.isEmpty) {
                  return EmptyState(
                    icon: Icons.kitchen_outlined,
                    title: 'Your pantry is empty',
                    subtitle:
                        'Add ingredients you have at home to get recipe suggestions.',
                    ctaLabel: 'Add Ingredient',
                    onCta: _showAddSheet,
                  );
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      'No items in $_selectedCategory',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: colors.textSecondary),
                    ),
                  );
                }

                // Group by category
                final grouped = <String, List<PantryItem>>{};
                for (final item in filtered) {
                  grouped
                      .putIfAbsent(item.category, () => [])
                      .add(item);
                }

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: grouped.entries.map((entry) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: 8, top: 4),
                          child: Row(
                            children: [
                              Text(
                                _categoryEmoji(entry.key),
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                entry.key,
                                style: AppTextStyles.labelLarge.copyWith(
                                    color: colors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        ...entry.value.map((item) => Dismissible(
                              key: Key(item.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding:
                                    const EdgeInsets.only(right: 16),
                                decoration: BoxDecoration(
                                  color: AppColors.error
                                      .withOpacity(0.1),
                                  borderRadius:
                                      BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.delete_outline,
                                    color: AppColors.error),
                              ),
                              onDismissed: (_) => _deleteItem(item.id),
                              child: _PantryItemTile(
                                  item: item, colors: colors),
                            )),
                        const SizedBox(height: 8),
                      ],
                    );
                  }).toList(),
                );
              },
              loading: () => ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 6,
                itemBuilder: (_, __) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: SkeletonLoader(
                      width: double.infinity,
                      height: 56,
                      borderRadius: 12),
                ),
              ),
              error: (e, _) => Center(
                  child: Text(friendlyError(e),
                      style: AppTextStyles.bodySmall)),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          pantryAsync.maybeWhen(
            data: (items) => items.isNotEmpty
                ? FloatingActionButton.extended(
                    heroTag: 'suggest',
                    onPressed: () => _showSuggestions(items),
                    backgroundColor: colors.surface,
                    foregroundColor: AppColors.primary,
                    elevation: 1,
                    icon: const IntelligenceGlyph(size: 20),
                    label: Text(
                      'What can I cook?',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600),
                    ),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'add',
            onPressed: _showAddSheet,
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _PantryItemTile extends StatelessWidget {
  final PantryItem item;
  final AppColorScheme colors;

  const _PantryItemTile({required this.item, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Text(
            _categoryEmoji(item.category),
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.name,
              style: AppTextStyles.bodyMedium,
            ),
          ),
          if (item.quantity.isNotEmpty)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                item.quantity,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
