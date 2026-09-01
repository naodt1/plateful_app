import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'pro_gate.dart';

/// Explains the free import allowance before the paywall appears.
///
/// Shown the moment a free user tries to import past their allowance. Landing
/// straight on a purchase screen right after sharing a link reads as a bait and
/// switch, so the user is told what happened and why first, then continues to
/// the paywall.
///
/// Returns true if the user chose to continue to Plateful Pro. The caller owns
/// the purchase flow, which keeps this sheet free of billing logic.
class ImportLimitSheet {
  static Future<bool> show(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const _LimitSheetBody(),
    );
    return result ?? false;
  }
}

class _LimitSheetBody extends StatelessWidget {
  const _LimitSheetBody();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      // Scrollable so the copy and both buttons stay reachable on short
      // screens rather than overflowing the sheet.
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          12,
          24,
          24 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Grab handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome,
                  color: AppColors.accent, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              'You have used your ${ProLimits.freeImports} free imports',
              style: AppTextStyles.headingMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Every recipe saved from a link is read and written up by AI, '
              'which costs us on each import. Plateful Pro removes the limit. '
              'Recipes you have already saved stay yours, and you can still add '
              'recipes by hand for free.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: colors.textSecondary, height: 1.45),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 52),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('See Plateful Pro',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context, false),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  foregroundColor: colors.textSecondary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Not now',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
