import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Text styles intentionally do NOT hardcode a color so they inherit the
/// brightness-aware color from the active theme's DefaultTextStyle. Use
/// `.copyWith(color: ...)` at the call site only when a specific (e.g.
/// secondary or accent) color is needed.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle get displayLarge => GoogleFonts.playfairDisplay(
        fontSize: 34,
        fontWeight: FontWeight.w700,
      );

  static TextStyle get displayMedium => GoogleFonts.playfairDisplay(
        fontSize: 28,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get headingLarge => GoogleFonts.playfairDisplay(
        fontSize: 22,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get headingMedium => GoogleFonts.playfairDisplay(
        fontSize: 18,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 16,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 14,
      );

  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: 13,
      );

  static TextStyle get labelLarge => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get labelMedium => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 12,
      );
}
