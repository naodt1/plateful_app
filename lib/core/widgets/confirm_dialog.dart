import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// A consistent, good-looking confirmation dialog used app-wide.
/// Both buttons are equal-width, stacked vertically, with the primary action
/// on top. Returns true if the user confirmed.
class ConfirmDialog {
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool destructive = false,
    IconData? icon,
  }) async {
    final colors = AppColors.of(context);
    final accent = destructive ? AppColors.error : AppColors.primary;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: colors.bg,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: accent, size: 28),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                title,
                style: AppTextStyles.headingMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                message,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: colors.textSecondary, height: 1.45),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 52),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(confirmLabel,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    foregroundColor: colors.textSecondary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(cancelLabel,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return result ?? false;
  }
}
