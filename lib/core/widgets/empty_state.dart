import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'airbnb_button.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? ctaLabel;
  final VoidCallback? onCta;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.ctaLabel,
    this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colors.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: AppColors.primary),
            ).animate().scale(duration: 300.ms, curve: Curves.easeOut),
            const SizedBox(height: 20),
            Text(title, style: AppTextStyles.headingMedium, textAlign: TextAlign.center)
                .animate()
                .fadeIn(delay: 100.ms),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: AppTextStyles.bodyMedium.copyWith(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 150.ms),
            if (ctaLabel != null && onCta != null) ...[
              const SizedBox(height: 24),
              AirbnbButton(label: ctaLabel!, onPressed: onCta!)
                  .animate()
                  .fadeIn(delay: 200.ms),
            ],
          ],
        ),
      ),
    );
  }
}
