import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/recipe.dart';

class NutritionGrid extends StatelessWidget {
  final Nutrition nutrition;

  const NutritionGrid({super.key, required this.nutrition});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    final protein = nutrition.protein;
    final carbs = nutrition.carbs;
    final fat = nutrition.fat;
    final totalG = (protein + carbs + fat);
    // Each gram → calories (4/4/9) for an honest macro split.
    final pCal = protein * 4;
    final cCal = carbs * 4;
    final fCal = fat * 9;
    final calTotal = (pCal + cCal + fCal);

    double pct(double part) => calTotal <= 0 ? 0 : part / calTotal;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          // ── Calories headline ────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.local_fire_department_rounded,
                    color: AppColors.accent, size: 26),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Calories',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: colors.textSecondary)),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('${nutrition.calories}',
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: colors.textPrimary)),
                      const SizedBox(width: 4),
                      Text('kcal',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: colors.textSecondary)),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              if (totalG > 0)
                Text('per serving',
                    style: AppTextStyles.caption
                        .copyWith(color: colors.textSecondary)),
            ],
          ),

          const SizedBox(height: 18),

          // ── Macro distribution bar ───────────────────────────────────
          if (calTotal > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    Expanded(
                      flex: (pct(pCal) * 1000).round().clamp(1, 1000),
                      child: Container(color: const Color(0xFF4F9D69)),
                    ),
                    Expanded(
                      flex: (pct(cCal) * 1000).round().clamp(1, 1000),
                      child: Container(color: AppColors.accent),
                    ),
                    Expanded(
                      flex: (pct(fCal) * 1000).round().clamp(1, 1000),
                      child: Container(color: const Color(0xFFE0A33E)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Macro rows ───────────────────────────────────────────────
          _MacroRow(
            color: const Color(0xFF4F9D69),
            label: 'Protein',
            grams: protein,
            percent: pct(pCal),
            colors: colors,
          ),
          const SizedBox(height: 12),
          _MacroRow(
            color: AppColors.accent,
            label: 'Carbs',
            grams: carbs,
            percent: pct(cCal),
            colors: colors,
          ),
          const SizedBox(height: 12),
          _MacroRow(
            color: const Color(0xFFE0A33E),
            label: 'Fat',
            grams: fat,
            percent: pct(fCal),
            colors: colors,
          ),
        ],
      ),
    );
  }
}

class _MacroRow extends StatelessWidget {
  final Color color;
  final String label;
  final double grams;
  final double percent;
  final AppColorScheme colors;

  const _MacroRow({
    required this.color,
    required this.label,
    required this.grams,
    required this.percent,
    required this.colors,
  });

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Text(label,
            style: AppTextStyles.bodyMedium
                .copyWith(color: colors.textPrimary, fontWeight: FontWeight.w600)),
        const Spacer(),
        Text('${_fmt(grams)}g',
            style: AppTextStyles.bodyMedium
                .copyWith(color: colors.textPrimary, fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: colors.bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.border),
          ),
          child: Text('${(percent * 100).round()}%',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary)),
        ),
      ],
    );
  }
}
