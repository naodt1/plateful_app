import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class ServingsAdjuster extends StatelessWidget {
  final int servings;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const ServingsAdjuster({
    super.key,
    required this.servings,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _AdjustButton(icon: Icons.remove, onTap: servings > 1 ? onDecrement : null),
        const SizedBox(width: 12),
        Text(
          '$servings ${servings == 1 ? 'serving' : 'servings'}',
          style: AppTextStyles.labelLarge,
        ),
        const SizedBox(width: 12),
        _AdjustButton(icon: Icons.add, onTap: onIncrement),
      ],
    );
  }
}

class _AdjustButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _AdjustButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: onTap != null ? AppColors.primary : AppColors.of(context).border,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}
