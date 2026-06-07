import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AirbnbCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final double borderRadius;
  final Color? color;

  const AirbnbCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.borderRadius = 16,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding ?? const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color ?? colors.surface,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: colors.border),
        ),
        child: child,
      ),
    );
  }
}
