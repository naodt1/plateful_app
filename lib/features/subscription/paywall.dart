import 'package:flutter/material.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/meta_ads_service.dart';
import '../../core/services/revenuecat_service.dart';

/// Presents the RevenueCat-hosted Paywall (configured in the dashboard).
///
/// Usage:
/// ```dart
/// final unlocked = await PlatefulPaywall.present(context);
/// if (unlocked) { /* user is now Plateful Pro */ }
/// ```
class PlatefulPaywall {
  /// Shows the paywall unless the user is already Pro. Returns true if they
  /// hold Pro once it closes.
  static Future<bool> present(BuildContext context) async {
    final svc = RevenueCatService.instance;
    // Check entitlement ourselves rather than via presentPaywallIfNeeded,
    // which matches the dashboard entitlement id exactly and would show a
    // paywall to a paying customer if that id ever drifts.
    if (svc.isPro) return true;
    return forcePresent(context);
  }

  /// Present the paywall regardless of current entitlement (an explicit
  /// "Upgrade" tap). Returns Pro status afterwards.
  ///
  /// If billing is unreachable or no products are live, this says so plainly
  /// and offers Restore, instead of failing into a dead end the user cannot
  /// act on.
  static Future<bool> forcePresent(BuildContext context) async {
    final svc = RevenueCatService.instance;

    if (!await svc.ensureConfigured()) {
      if (context.mounted) await _unavailable(context);
      return svc.isPro;
    }
    if (!await svc.canPurchase()) {
      if (context.mounted) await _unavailable(context);
      return svc.isPro;
    }

    try {
      final result =
          await RevenueCatUI.presentPaywall(displayCloseButton: true);
      if (result == PaywallResult.purchased ||
          result == PaywallResult.restored) {
        // Pull authoritative state rather than trusting the result alone.
        await svc.refresh();
        if (svc.isPro) {
          if (result == PaywallResult.purchased) {
            Analytics.purchaseCompleted();
            await _reportConversion(svc);
          } else {
            Analytics.purchaseRestored();
          }
        }
      }
      return svc.isPro;
    } catch (e) {
      debugPrint('Paywall present failed: $e');
      if (context.mounted) await _unavailable(context);
      return svc.isPro;
    }
  }

  /// Reports a new subscription to Meta so ad campaigns can optimise on it.
  /// Price is looked up from the offering; when it cannot be resolved the
  /// conversion is still sent, just without a value.
  static Future<void> _reportConversion(RevenueCatService svc) async {
    final p = await svc.activeSubscriptionPrice();
    await MetaAds.subscribed(
      orderId: p?.productId ?? 'unknown',
      price: p?.price,
      currency: p?.currency,
      isTrial: svc.isInTrial,
    );
  }

  /// Shown when the store cannot be reached or has nothing to sell. Always
  /// offers Restore, which is the recovery path for someone who already paid
  /// but is not being recognised as Pro.
  static Future<void> _unavailable(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final restore = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Plateful Pro is unavailable'),
        content: const Text(
          'We could not reach the store just now. Check your connection and '
          'try again.\n\nIf you have already subscribed, restore your purchase '
          'to unlock Pro on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore purchase'),
          ),
        ],
      ),
    );
    if (restore != true) return;

    final result = await RevenueCatService.instance.restore();
    if (result.success) Analytics.purchaseRestored();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.success
              ? 'Plateful Pro restored.'
              : result.error ?? 'No previous purchase found on this account.',
        ),
      ),
    );
  }
}
