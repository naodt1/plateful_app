import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import '../../core/services/revenuecat_service.dart';
import '../../core/utils/error_messages.dart';

/// Presents the RevenueCat-hosted Paywall (configured in the dashboard).
///
/// Usage:
/// ```dart
/// final unlocked = await PlatefulPaywall.present(context);
/// if (unlocked) { /* user is now Plateful Pro */ }
/// ```
class PlatefulPaywall {
  /// Shows the paywall as a full-screen modal. Returns true if, after the
  /// paywall closes, the user holds the Plateful Pro entitlement.
  static Future<bool> present(BuildContext context) async {
    final svc = RevenueCatService.instance;

    // Only show if the user isn't already Pro.
    if (svc.isPro) return true;

    try {
      // Presents the paywall for the entitlement; RevenueCat returns the
      // result of the interaction (purchased / restored / cancelled / error).
      final result = await RevenueCatUI.presentPaywallIfNeeded(
        RevenueCatService.entitlementId,
        displayCloseButton: true,
      );

      switch (result) {
        case PaywallResult.purchased:
        case PaywallResult.restored:
          // Refresh entitlement state.
          svc.customerInfo.value = await Purchases.getCustomerInfo();
          return svc.isPro;
        case PaywallResult.cancelled:
        case PaywallResult.error:
        case PaywallResult.notPresented:
          return svc.isPro;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e))),
        );
      }
      return svc.isPro;
    }
  }

  /// Force-present the paywall even if the user could already be Pro
  /// (e.g. from an explicit "Upgrade" tap). Returns Pro status afterwards.
  static Future<bool> forcePresent(BuildContext context) async {
    final svc = RevenueCatService.instance;
    try {
      final result =
          await RevenueCatUI.presentPaywall(displayCloseButton: true);
      if (result == PaywallResult.purchased ||
          result == PaywallResult.restored) {
        svc.customerInfo.value = await Purchases.getCustomerInfo();
      }
      return svc.isPro;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e))),
        );
      }
      return svc.isPro;
    }
  }
}
