import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ─── Shared ──────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF2E7D5B); // main brand green (healthiness)
  static const Color accent = Color(0xFFF2A03D); // warm orange accent
  // Functional colors reuse the brand palette — only green + orange in the app.
  static const Color success = primary;
  static const Color warning = accent;
  static const Color error = Color(0xFFE5533D); // reserved for destructive only

  // ─── Light (existing) ─────────────────────────────────────────────────────
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF7F7F7);
  static const Color textPrimary = Color(0xFF222222);
  static const Color textSecondary = Color(0xFF717171);
  static const Color border = Color(0xFFEBEBEB);
  static const Color cardDark = Color(0xFF1A1A1A);

  // ─── Dark ─────────────────────────────────────────────────────────────────
  static const Color darkBackground = Color(0xFF0D0D0D);
  static const Color darkSurface = Color(0xFF1A1A1A);
  static const Color darkCard = Color(0xFF242424);
  static const Color darkTextPrimary = Color(0xFFF5F5F5);
  static const Color darkTextSecondary = Color(0xFF888888);
  static const Color darkBorder = Color(0xFF2C2C2C);

  // ─── Context-aware accessors ──────────────────────────────────────────────
  static AppColorScheme of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const _DarkScheme() : const _LightScheme();
  }
}

abstract class AppColorScheme {
  const AppColorScheme();

  Color get bg;
  Color get surface;
  Color get card;
  Color get textPrimary;
  Color get textSecondary;
  Color get border;

  Color get primary => AppColors.primary;
  Color get accent => AppColors.accent;
  Color get error => AppColors.error;
  Color get success => AppColors.success;
  Color get warning => AppColors.warning;
}

class _LightScheme extends AppColorScheme {
  const _LightScheme();

  @override
  Color get bg => AppColors.background;
  @override
  Color get surface => AppColors.surface;
  @override
  Color get card => AppColors.surface;
  @override
  Color get textPrimary => AppColors.textPrimary;
  @override
  Color get textSecondary => AppColors.textSecondary;
  @override
  Color get border => AppColors.border;
}

class _DarkScheme extends AppColorScheme {
  const _DarkScheme();

  @override
  Color get bg => AppColors.darkBackground;
  @override
  Color get surface => AppColors.darkSurface;
  @override
  Color get card => AppColors.darkCard;
  @override
  Color get textPrimary => AppColors.darkTextPrimary;
  @override
  Color get textSecondary => AppColors.darkTextSecondary;
  @override
  Color get border => AppColors.darkBorder;
}
