import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/recipe.dart';

class IngredientRow extends StatefulWidget {
  final Ingredient ingredient;
  final int index;

  const IngredientRow({super.key, required this.ingredient, required this.index});

  @override
  State<IngredientRow> createState() => _IngredientRowState();
}

class _IngredientRowState extends State<IngredientRow> {
  bool _checked = false;

  // Map ingredient name keywords to emoji icons
  String _emojiFor(String name) {
    final n = name.toLowerCase();
    if (_matches(n, ['chicken', 'turkey', 'duck', 'poultry'])) return '🍗';
    if (_matches(n, ['beef', 'steak', 'mince', 'ground beef', 'lamb', 'pork', 'bacon', 'ham', 'sausage', 'meat'])) return '🥩';
    if (_matches(n, ['salmon', 'tuna', 'fish', 'shrimp', 'prawn', 'cod', 'tilapia', 'seafood'])) return '🐟';
    if (_matches(n, ['egg', 'eggs'])) return '🥚';
    if (_matches(n, ['milk', 'cream', 'yogurt', 'yoghurt', 'buttermilk'])) return '🥛';
    if (_matches(n, ['cheese', 'mozzarella', 'parmesan', 'cheddar', 'feta', 'ricotta'])) return '🧀';
    if (_matches(n, ['butter'])) return '🧈';
    if (_matches(n, ['bread', 'baguette', 'toast', 'sourdough', 'roll', 'bun'])) return '🍞';
    if (_matches(n, ['rice', 'basmati', 'jasmine rice'])) return '🍚';
    if (_matches(n, ['pasta', 'spaghetti', 'noodle', 'penne', 'fettuccine', 'linguine', 'macaroni'])) return '🍝';
    if (_matches(n, ['potato', 'potatoes', 'sweet potato'])) return '🥔';
    if (_matches(n, ['carrot', 'carrots'])) return '🥕';
    if (_matches(n, ['broccoli'])) return '🥦';
    if (_matches(n, ['corn', 'sweetcorn'])) return '🌽';
    if (_matches(n, ['pepper', 'bell pepper', 'capsicum', 'chili', 'chilli', 'jalapeño'])) return '🌶️';
    if (_matches(n, ['tomato', 'tomatoes', 'cherry tomato'])) return '🍅';
    if (_matches(n, ['onion', 'shallot', 'spring onion', 'scallion', 'leek'])) return '🧅';
    if (_matches(n, ['garlic'])) return '🧄';
    if (_matches(n, ['lemon', 'lime'])) return '🍋';
    if (_matches(n, ['orange'])) return '🍊';
    if (_matches(n, ['apple'])) return '🍎';
    if (_matches(n, ['banana'])) return '🍌';
    if (_matches(n, ['avocado'])) return '🥑';
    if (_matches(n, ['mushroom', 'mushrooms'])) return '🍄';
    if (_matches(n, ['lettuce', 'spinach', 'kale', 'arugula', 'salad', 'greens', 'herb', 'basil', 'parsley', 'cilantro', 'coriander', 'mint', 'thyme', 'rosemary'])) return '🌿';
    if (_matches(n, ['flour', 'cornstarch', 'starch', 'cornflour'])) return '🌾';
    if (_matches(n, ['sugar', 'honey', 'syrup', 'molasses', 'agave'])) return '🍯';
    if (_matches(n, ['oil', 'olive oil', 'vegetable oil', 'coconut oil'])) return '🫙';
    if (_matches(n, ['salt', 'pepper', 'spice', 'cumin', 'paprika', 'turmeric', 'cinnamon', 'oregano', 'seasoning'])) return '🧂';
    if (_matches(n, ['water', 'broth', 'stock', 'wine', 'vinegar', 'sauce', 'soy sauce', 'worcestershire'])) return '🫗';
    if (_matches(n, ['chocolate', 'cocoa', 'cacao'])) return '🍫';
    if (_matches(n, ['vanilla', 'baking powder', 'baking soda', 'yeast'])) return '🧁';
    if (_matches(n, ['almond', 'walnut', 'cashew', 'peanut', 'nut', 'pecan', 'pistachio'])) return '🥜';
    if (_matches(n, ['bean', 'lentil', 'chickpea', 'legume', 'tofu'])) return '🫘';
    return '🥄';
  }

  bool _matches(String name, List<String> keywords) =>
      keywords.any((k) => name.contains(k));

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _checked = !_checked),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.of(context).surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.of(context).border),
        ),
        child: Row(
          children: [
            // Small emoji inline
            Text(
              _emojiFor(widget.ingredient.name),
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(width: 8),
            // Name
            Expanded(
              child: Text(
                widget.ingredient.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  decoration: _checked ? TextDecoration.lineThrough : null,
                  color: _checked
                      ? AppColors.of(context).textSecondary
                      : AppColors.of(context).textPrimary,
                ),
              ),
            ),
            // Amount
            Text(
              '${_formatAmount(widget.ingredient.amount)} ${widget.ingredient.unit}'.trim(),
              style: TextStyle(
                fontSize: 12,
                color: AppColors.of(context).textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(width: 8),
            // Mini checkbox
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: _checked ? AppColors.primary : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: _checked ? AppColors.primary : AppColors.of(context).border,
                  width: 1.5,
                ),
              ),
              child: _checked
                  ? const Icon(Icons.check, color: Colors.white, size: 11)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount == amount.roundToDouble()) return amount.round().toString();
    return amount.toStringAsFixed(1);
  }
}
