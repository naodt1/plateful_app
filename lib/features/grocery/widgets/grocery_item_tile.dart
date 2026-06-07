import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/grocery_item.dart';

class GroceryItemTile extends StatelessWidget {
  final GroceryItem item;
  final void Function(bool) onToggle;
  final VoidCallback? onDelete;

  const GroceryItemTile({
    super.key,
    required this.item,
    required this.onToggle,
    this.onDelete,
  });

  // Map ingredient name keywords → emoji
  static String emojiFor(String name) {
    final n = name.toLowerCase();
    if (_has(n, ['chicken', 'turkey', 'duck', 'poultry'])) return '🍗';
    if (_has(n, ['beef', 'steak', 'mince', 'ground beef', 'lamb', 'pork', 'bacon', 'ham', 'sausage'])) return '🥩';
    if (_has(n, ['salmon', 'tuna', 'fish', 'shrimp', 'prawn', 'cod', 'tilapia', 'seafood'])) return '🐟';
    if (_has(n, ['egg', 'eggs'])) return '🥚';
    if (_has(n, ['milk', 'cream', 'yogurt', 'yoghurt', 'buttermilk'])) return '🥛';
    if (_has(n, ['cheese', 'mozzarella', 'parmesan', 'cheddar', 'feta', 'ricotta'])) return '🧀';
    if (_has(n, ['butter'])) return '🧈';
    if (_has(n, ['bread', 'baguette', 'toast', 'sourdough', 'roll', 'bun'])) return '🍞';
    if (_has(n, ['rice', 'basmati', 'jasmine rice'])) return '🍚';
    if (_has(n, ['pasta', 'spaghetti', 'noodle', 'penne', 'fettuccine', 'macaroni'])) return '🍝';
    if (_has(n, ['potato', 'potatoes', 'sweet potato'])) return '🥔';
    if (_has(n, ['carrot', 'carrots'])) return '🥕';
    if (_has(n, ['broccoli'])) return '🥦';
    if (_has(n, ['corn', 'sweetcorn'])) return '🌽';
    if (_has(n, ['pepper', 'bell pepper', 'capsicum', 'chili', 'chilli', 'jalapeño'])) return '🌶️';
    if (_has(n, ['tomato', 'tomatoes', 'cherry tomato'])) return '🍅';
    if (_has(n, ['onion', 'shallot', 'spring onion', 'scallion', 'leek'])) return '🧅';
    if (_has(n, ['garlic'])) return '🧄';
    if (_has(n, ['lemon', 'lime'])) return '🍋';
    if (_has(n, ['orange'])) return '🍊';
    if (_has(n, ['apple'])) return '🍎';
    if (_has(n, ['banana'])) return '🍌';
    if (_has(n, ['avocado'])) return '🥑';
    if (_has(n, ['mushroom', 'mushrooms'])) return '🍄';
    if (_has(n, ['lettuce', 'spinach', 'kale', 'arugula', 'salad', 'greens', 'herb', 'basil', 'parsley', 'cilantro', 'mint', 'thyme', 'rosemary'])) return '🌿';
    if (_has(n, ['flour', 'cornstarch', 'starch'])) return '🌾';
    if (_has(n, ['sugar', 'honey', 'syrup', 'molasses', 'agave'])) return '🍯';
    if (_has(n, ['oil', 'olive oil', 'vegetable oil', 'coconut oil'])) return '🫙';
    if (_has(n, ['salt', 'pepper', 'spice', 'cumin', 'paprika', 'turmeric', 'cinnamon', 'oregano', 'seasoning'])) return '🧂';
    if (_has(n, ['water', 'broth', 'stock', 'wine', 'vinegar', 'sauce', 'soy sauce'])) return '🫗';
    if (_has(n, ['chocolate', 'cocoa', 'cacao'])) return '🍫';
    if (_has(n, ['vanilla', 'baking powder', 'baking soda', 'yeast'])) return '🧁';
    if (_has(n, ['almond', 'walnut', 'cashew', 'peanut', 'nut', 'pecan', 'pistachio'])) return '🥜';
    if (_has(n, ['bean', 'lentil', 'chickpea', 'legume', 'tofu'])) return '🫘';
    if (_has(n, ['coffee', 'tea', 'juice', 'soda', 'drink', 'beverage'])) return '☕';
    if (_has(n, ['yogurt', 'yoghurt'])) return '🥛';
    return '🛒';
  }

  static bool _has(String name, List<String> keywords) =>
      keywords.any((k) => name.contains(k));

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final emoji = emojiFor(item.name);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: item.checked
            ? colors.surface.withValues(alpha: 0.5)
            : colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.checked
              ? colors.border.withValues(alpha: 0.4)
              : colors.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Emoji in a small accent-tinted bubble
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: item.checked
                    ? colors.border.withValues(alpha: 0.4)
                    : AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  emoji,
                  style: TextStyle(
                    fontSize: 17,
                    color: item.checked
                        ? colors.textSecondary.withValues(alpha: 0.5)
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Name + quantity
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      decoration: item.checked ? TextDecoration.lineThrough : null,
                      color: item.checked
                          ? colors.textSecondary
                          : colors.textPrimary,
                    ),
                  ),
                  if (item.quantity.isNotEmpty)
                    Text(
                      item.quantity,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: item.checked
                            ? colors.textSecondary.withValues(alpha: 0.5)
                            : AppColors.accent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Checkbox
            GestureDetector(
              onTap: () => onToggle(!item.checked),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: item.checked ? AppColors.primary : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: item.checked ? AppColors.primary : colors.border,
                    width: 1.5,
                  ),
                ),
                child: item.checked
                    ? const Icon(Icons.check, color: Colors.white, size: 13)
                    : null,
              ),
            ),
            // Delete
            GestureDetector(
              onTap: onDelete,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(Icons.close,
                    size: 14,
                    color: colors.textSecondary.withValues(alpha: 0.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
