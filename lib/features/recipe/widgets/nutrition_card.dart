import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/recipe.dart';

// Distinct macro hues — green / orange / violet so no two read alike.
const Color _proteinColor = Color(0xFF4F9D69);
const Color _carbsColor = Color(0xFFF2A03D);
const Color _fatColor = Color(0xFF7C6CE4);

class NutritionGrid extends StatelessWidget {
  final Nutrition nutrition;

  const NutritionGrid({super.key, required this.nutrition});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    final protein = nutrition.protein;
    final carbs = nutrition.carbs;
    final fat = nutrition.fat;
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
      child: calTotal <= 0
          // No macro data — just show the calorie headline.
          ? _CalorieHeadline(calories: nutrition.calories, colors: colors)
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _MacroDonut(
                  calories: nutrition.calories,
                  proteinPct: pct(pCal),
                  carbsPct: pct(cCal),
                  fatPct: pct(fCal),
                  colors: colors,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Per serving',
                          style: AppTextStyles.caption
                              .copyWith(color: colors.textSecondary)),
                      const SizedBox(height: 10),
                      _MacroRow(
                        color: _proteinColor,
                        label: 'Protein',
                        grams: protein,
                        percent: pct(pCal),
                        colors: colors,
                      ),
                      const SizedBox(height: 10),
                      _MacroRow(
                        color: _carbsColor,
                        label: 'Carbs',
                        grams: carbs,
                        percent: pct(cCal),
                        colors: colors,
                      ),
                      const SizedBox(height: 10),
                      _MacroRow(
                        color: _fatColor,
                        label: 'Fat',
                        grams: fat,
                        percent: pct(fCal),
                        colors: colors,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// Fallback headline used when there's no macro breakdown to chart.
class _CalorieHeadline extends StatelessWidget {
  final int calories;
  final AppColorScheme colors;
  const _CalorieHeadline({required this.calories, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Row(
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('$calories',
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
        const Spacer(),
        Text('per serving',
            style: AppTextStyles.caption.copyWith(color: colors.textSecondary)),
      ],
    );
  }
}

/// A donut ring of the three macro proportions with the calorie total centered.
class _MacroDonut extends StatelessWidget {
  final int calories;
  final double proteinPct;
  final double carbsPct;
  final double fatPct;
  final AppColorScheme colors;

  const _MacroDonut({
    required this.calories,
    required this.proteinPct,
    required this.carbsPct,
    required this.fatPct,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    const size = 116.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(size, size),
            painter: _DonutPainter(
              proteinPct: proteinPct,
              carbsPct: carbsPct,
              fatPct: fatPct,
              track: colors.border,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                child: Text('$calories',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary)),
              ),
              Text('kcal',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double proteinPct;
  final double carbsPct;
  final double fatPct;
  final Color track;

  _DonutPainter({
    required this.proteinPct,
    required this.carbsPct,
    required this.fatPct,
    required this.track,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 15.0;
    final rect = const Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);

    // Faint background track so the ring reads as a full circle.
    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );

    const gap = 0.10; // small radial gap between segments for separation
    var start = -math.pi / 2; // start at 12 o'clock

    void segment(double frac, Color color) {
      if (frac <= 0) return;
      final full = 2 * math.pi * frac;
      final sweep = full - gap;
      if (sweep > 0) {
        canvas.drawArc(
          rect,
          start + gap / 2,
          sweep,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.round
            ..color = color,
        );
      }
      start += full;
    }

    segment(proteinPct, _proteinColor);
    segment(carbsPct, _carbsColor);
    segment(fatPct, _fatColor);
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.proteinPct != proteinPct ||
      old.carbsPct != carbsPct ||
      old.fatPct != fatPct ||
      old.track != track;
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
        Expanded(
          child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyMedium.copyWith(
                  color: colors.textPrimary, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 6),
        Text('${_fmt(grams)}g',
            style: AppTextStyles.bodyMedium.copyWith(
                color: colors.textPrimary, fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        Text('${(percent * 100).round()}%',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: colors.textSecondary)),
      ],
    );
  }
}
