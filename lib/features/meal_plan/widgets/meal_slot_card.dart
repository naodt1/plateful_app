import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/meal_plan.dart';

class MealSlotCard extends StatelessWidget {
  final String mealType;
  final MealSlot? slot;
  final VoidCallback? onTap;

  const MealSlotCard({
    super.key,
    required this.mealType,
    this.slot,
    this.onTap,
  });

  IconData get _icon => switch (mealType.toLowerCase()) {
        'breakfast' => Icons.wb_sunny_outlined,
        'lunch' => Icons.lunch_dining_outlined,
        'dinner' => Icons.dinner_dining_outlined,
        'snack' => Icons.cookie_outlined,
        _ => Icons.restaurant_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final hasRecipe = (slot?.recipeTitle ?? '').isNotEmpty;
    final image = slot?.recipeImage;
    final hasImage = image != null && image.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasRecipe ? AppColors.primary : colors.border,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 44,
                height: 44,
                child: hasImage
                    ? Image.network(
                        image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _IconBox(
                            icon: _icon, hasRecipe: hasRecipe, colors: colors),
                      )
                    : _IconBox(
                        icon: _icon, hasRecipe: hasRecipe, colors: colors),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mealType[0].toUpperCase() + mealType.substring(1),
                    style: AppTextStyles.caption.copyWith(color: colors.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    slot?.recipeTitle ?? 'Tap to add',
                    style: hasRecipe
                        ? AppTextStyles.labelLarge.copyWith(color: colors.textPrimary)
                        : AppTextStyles.bodyMedium
                            .copyWith(color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(
              hasRecipe ? Icons.edit_outlined : Icons.add_circle_outline,
              color: hasRecipe ? AppColors.primary : colors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  final IconData icon;
  final bool hasRecipe;
  final AppColorScheme colors;

  const _IconBox({
    required this.icon,
    required this.hasRecipe,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: hasRecipe
          ? AppColors.primary.withValues(alpha: 0.1)
          : colors.border,
      child: Icon(
        icon,
        size: 20,
        color: hasRecipe ? AppColors.primary : colors.textSecondary,
      ),
    );
  }
}
