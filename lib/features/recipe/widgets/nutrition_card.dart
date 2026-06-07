import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/recipe.dart';

class NutritionGrid extends StatelessWidget {
  final Nutrition nutrition;

  const NutritionGrid({super.key, required this.nutrition});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _MacroCard(
          label: 'Calories',
          value: '${nutrition.calories}',
          unit: 'kcal',
          color: AppColors.accent,
          icon: Icons.local_fire_department,
        ),
        _MacroCard(
          label: 'Protein',
          value: nutrition.protein.toStringAsFixed(1),
          unit: 'g',
          color: AppColors.accent,
          icon: Icons.fitness_center,
        ),
        _MacroCard(
          label: 'Carbs',
          value: nutrition.carbs.toStringAsFixed(1),
          unit: 'g',
          color: AppColors.accent,
          icon: Icons.grain,
        ),
        _MacroCard(
          label: 'Fat',
          value: nutrition.fat.toStringAsFixed(1),
          unit: 'g',
          color: AppColors.accent,
          icon: Icons.water_drop,
        ),
      ],
    );
  }
}

class _MacroCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  final IconData icon;

  const _MacroCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(color: color),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(width: 2),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  unit,
                  style: TextStyle(
                    fontSize: 12,
                    color: color.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
