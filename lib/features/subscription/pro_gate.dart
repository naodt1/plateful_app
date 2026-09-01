import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/meta_ads_service.dart';
import '../../core/services/revenuecat_service.dart';
import 'import_credits.dart';
import 'paywall.dart';

/// Free-tier limits. Once a free user crosses these, the paywall appears.
class ProLimits {
  /// How many AI recipe imports/extractions a free user gets before Pro.
  static const int freeImports = 15;
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
  ///
  /// When the allowance is spent, explain what happened before showing the
  /// paywall. Dropping someone straight onto a purchase screen right after
  /// they shared a link reads as a bait and switch, so the explanation comes
  /// first and the paywall follows from it.
  static Future<bool> allowImport(BuildContext context) async {
    if (RevenueCatService.instance.isPro) return true;

    final prefs = await SharedPreferences.getInstance();
    final used = prefs.getInt(ProLimits._importCountKey) ?? 0;

    if (used < ProLimits.freeImports) {
      return true; // still within the free allowance
    }

    // The allowance is spent, but only gate the import if the user actually
    // has a way through. When billing is unavailable or no subscription
    // products are live yet, the paywall cannot be completed, so enforcing the
    // limit would lock the user out of the app permanently with no path back.
    // Fail open: a free import costs us far less than a trapped user.
    if (!await RevenueCatService.instance.canPurchase()) {
      debugPrint('ProGate: over the free limit but purchases are unavailable, '
          'allowing the import rather than trapping the user');
      Analytics.billingUnavailable();
      return true;
    }

    // Out of free imports: tell the user why, then take them to the paywall.
    if (!context.mounted) return false;
    Analytics.paywallShown('import_limit');
    MetaAds.initiatedCheckout();
    final wantsPro = await ImportLimitSheet.show(context);
    if (!wantsPro || !context.mounted) return false;
    final unlocked = await PlatefulPaywall.forcePresent(context);
    if (unlocked) Analytics.purchaseCompleted();
    return unlocked;
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
