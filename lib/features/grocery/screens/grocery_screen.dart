import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../models/grocery_item.dart';
import '../widgets/grocery_item_tile.dart';
import '../../../core/utils/error_messages.dart';

final _groceryProvider =
    FutureProvider.autoDispose<List<GroceryItem>>((ref) {
  return FirebaseService.getGroceryItems();
});

const _groceryCategories = [
  'Produce',
  'Dairy',
  'Meat',
  'Grains',
  'Frozen',
  'Beverages',
  'Other',
];

class GroceryScreen extends ConsumerStatefulWidget {
  const GroceryScreen({super.key});

  @override
  ConsumerState<GroceryScreen> createState() => _GroceryScreenState();
}

class _GroceryScreenState extends ConsumerState<GroceryScreen> {
  Future<void> _toggleItem(GroceryItem item, bool checked) async {
    await FirebaseService.updateGroceryItem(item.copyWith(checked: checked));
    ref.invalidate(_groceryProvider);
  }

  Future<void> _deleteItem(String id) async {
    await FirebaseService.deleteGroceryItem(id);
    ref.invalidate(_groceryProvider);
  }

  Future<void> _clearCompleted(List<GroceryItem> items) async {
    final checked = items.where((i) => i.checked).toList();
    for (final item in checked) {
      await FirebaseService.deleteGroceryItem(item.id);
    }
    ref.invalidate(_groceryProvider);
  }

  Future<void> _clearAll(List<GroceryItem> items) async {
    final confirm = await ConfirmDialog.show(
      context,
      title: 'Clear entire list?',
      message: 'This will remove all ${items.length} items.',
      confirmLabel: 'Clear All',
      destructive: true,
      icon: Icons.delete_sweep_outlined,
    );
    if (!confirm) return;
    for (final item in items) {
      await FirebaseService.deleteGroceryItem(item.id);
    }
    if (mounted) ref.invalidate(_groceryProvider);
  }

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    String selectedCat = 'Other';

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
                    Text('Add Item', style: AppTextStyles.headingMedium),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      decoration:
                          const InputDecoration(hintText: 'Item name'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: qtyCtrl,
                      decoration: const InputDecoration(
                          hintText: 'Quantity (e.g. 2 cups)'),
                    ),
                    const SizedBox(height: 16),
                    Text('Category',
                        style: AppTextStyles.labelLarge
                            .copyWith(color: colors.textSecondary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _groceryCategories.map((cat) {
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
                              cat,
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
                          final item = GroceryItem(
                            id: const Uuid().v4(),
                            userId: userId,
                            name: name,
                            category: selectedCat,
                            quantity: qtyCtrl.text.trim(),
                            checked: false,
                            createdAt: DateTime.now(),
                          );
                          await FirebaseService.addGroceryItem(item);
                          ref.invalidate(_groceryProvider);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: const Text('Add to List'),
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
    final groceryAsync = ref.watch(_groceryProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        title: Text('Grocery List', style: AppTextStyles.headingMedium),
        automaticallyImplyLeading: false,
        backgroundColor: colors.bg,
        actions: [
          groceryAsync.when(
            data: (items) {
              if (items.isEmpty) return const SizedBox();
              final checkedCount = items.where((i) => i.checked).length;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (checkedCount > 0)
                    TextButton(
                      onPressed: () => _clearCompleted(items),
                      child: Text(
                        'Clear done ($checkedCount)',
                        style: const TextStyle(
                            color: AppColors.error, fontSize: 13),
                      ),
                    ),
                  TextButton(
                    onPressed: () => _clearAll(items),
                    child: const Text(
                      'Clear all',
                      style: TextStyle(color: AppColors.error, fontSize: 13),
                    ),
                  ),
                ],
              );
            },
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),
        ],
      ),
      body: groceryAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'Your list is empty',
              subtitle: 'Add items manually or import from a recipe.',
              ctaLabel: 'Add Item',
              onCta: _showAddDialog,
            );
          }

          final pending = items.where((i) => !i.checked).toList();
          final checked = items.where((i) => i.checked).toList();

          // Group pending by category
          final grouped = <String, List<GroceryItem>>{};
          for (final item in pending) {
            grouped.putIfAbsent(item.category, () => []).add(item);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ...grouped.entries.map((entry) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CategoryHeader(
                        category: entry.key,
                        count: entry.value.length,
                        colors: colors,
                      ),
                      const SizedBox(height: 8),
                      ...entry.value.map((item) => Dismissible(
                            key: Key(item.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 16),
                              decoration: BoxDecoration(
                                color: AppColors.error.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.delete_outline,
                                  color: AppColors.error),
                            ),
                            onDismissed: (_) => _deleteItem(item.id),
                            child: GroceryItemTile(
                              item: item,
                              onToggle: (v) => _toggleItem(item, v),
                              onDelete: () => _deleteItem(item.id),
                            ),
                          )),
                      const SizedBox(height: 16),
                    ],
                  )),
              if (checked.isNotEmpty) ...[
                _CategoryHeader(
                  category: 'Completed',
                  count: checked.length,
                  colors: colors,
                  isCompleted: true,
                ),
                const SizedBox(height: 8),
                ...checked.map((item) => Dismissible(
                      key: Key(item.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.delete_outline,
                            color: AppColors.error),
                      ),
                      onDismissed: (_) => _deleteItem(item.id),
                      child: GroceryItemTile(
                        item: item,
                        onToggle: (v) => _toggleItem(item, v),
                        onDelete: () => _deleteItem(item.id),
                      ),
                    )),
              ],
            ],
          );
        },
        loading: () => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 6,
          itemBuilder: (_, __) => const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: SkeletonLoader(
                width: double.infinity, height: 60, borderRadius: 14),
          ),
        ),
        error: (e, _) => Center(
          child: Text(friendlyError(e), style: AppTextStyles.bodySmall),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// ── Category header ───────────────────────────────────────────────────────────
class _CategoryHeader extends StatelessWidget {
  final String category;
  final int count;
  final AppColorScheme colors;
  final bool isCompleted;

  const _CategoryHeader({
    required this.category,
    required this.count,
    required this.colors,
    this.isCompleted = false,
  });

  static const _categoryMeta = <String, ({String emoji, Color color})>{
    'Produce':   (emoji: '🥦', color: Color(0xFF4CAF50)),
    'Dairy':     (emoji: '🧀', color: Color(0xFFFFC107)),
    'Meat':      (emoji: '🥩', color: Color(0xFFE53935)),
    'Grains':    (emoji: '🌾', color: Color(0xFFFF8F00)),
    'Frozen':    (emoji: '❄️', color: Color(0xFF29B6F6)),
    'Beverages': (emoji: '🥤', color: Color(0xFF7E57C2)),
    'Other':     (emoji: '🛒', color: Color(0xFF78909C)),
  };

  @override
  Widget build(BuildContext context) {
    final meta = _categoryMeta[category];
    final emoji = isCompleted ? '✓' : (meta?.emoji ?? '🛒');
    final badgeColor = isCompleted ? AppColors.primary : (meta?.color ?? AppColors.accent);

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Row(
        children: [
          // Emoji bubble
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                emoji,
                style: TextStyle(
                  fontSize: isCompleted ? 14 : 16,
                  color: isCompleted ? AppColors.primary : null,
                  fontWeight: isCompleted ? FontWeight.w700 : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Category name
          Text(
            category,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 8),
          // Count badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: badgeColor,
              ),
            ),
          ),
          // Thin divider line
          const SizedBox(width: 10),
          Expanded(
            child: Divider(
              color: colors.border,
              thickness: 1,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
