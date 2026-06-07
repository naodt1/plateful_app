import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/revenuecat_service.dart';
import 'paywall.dart';

/// Free-tier limits. Once a free user crosses these, the paywall appears.
class ProLimits {
  /// How many AI recipe imports/extractions a free user gets before Pro.
  static const int freeImports = 5;
  static const String _importCountKey = 'free_import_count';
}

/// Helper for gating Pro-only features behind the RevenueCat paywall.
class ProGate {
  /// Ensure the user is Plateful Pro. If not, present the paywall and return
  /// whether they unlocked it. Use this before running a Pro-only action.
  ///
  /// ```dart
  /// if (!await ProGate.ensurePro(context)) return; // user stayed free
  /// // ...run the Pro feature
  /// ```
  static Future<bool> ensurePro(BuildContext context) async {
    if (RevenueCatService.instance.isPro) return true;
    // Present the paywall; returns true if they purchased/restored Pro.
    return PlatefulPaywall.forcePresent(context);
  }

  /// Gate for AI imports: Pro users are unlimited; free users get
  /// [ProLimits.freeImports] before the paywall appears. Returns true if the
  /// import may proceed.
  static Future<bool> allowImport(BuildContext context) async {
    if (RevenueCatService.instance.isPro) return true;

    final prefs = await SharedPreferences.getInstance();
    final used = prefs.getInt(ProLimits._importCountKey) ?? 0;

    if (used < ProLimits.freeImports) {
      return true; // still within the free allowance
    }
    // Out of free imports — present the paywall.
    if (!context.mounted) return false;
    return PlatefulPaywall.forcePresent(context);
  }

  /// Record that a free user consumed one import. No-op for Pro users.
  static Future<void> recordImport() async {
    if (RevenueCatService.instance.isPro) return;
    final prefs = await SharedPreferences.getInstance();
    final used = prefs.getInt(ProLimits._importCountKey) ?? 0;
    await prefs.setInt(ProLimits._importCountKey, used + 1);
  }

  /// How many free imports remain (for showing "X left" hints). -1 = unlimited.
  static Future<int> remainingImports() async {
    if (RevenueCatService.instance.isPro) return -1;
    final prefs = await SharedPreferences.getInstance();
    final used = prefs.getInt(ProLimits._importCountKey) ?? 0;
    return (ProLimits.freeImports - used).clamp(0, ProLimits.freeImports);
  }
}
