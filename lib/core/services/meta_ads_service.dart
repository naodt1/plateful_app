import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:flutter/foundation.dart';

/// Meta (Facebook) app events, used to attribute installs and conversions to
/// Facebook ad campaigns.
///
/// Separate from [Analytics] on purpose. Firebase answers "what are users
/// doing"; this answers "which ad did this user come from, and did they
/// convert". Only the handful of events Meta can actually optimise delivery
/// against are sent, because sending more does not improve targeting and does
/// widen what leaves the device.
///
/// Auto init and advertiser id collection are disabled in the manifest, so
/// nothing is collected until [init] runs and turns them on. That keeps debug
/// runs and any future consent flow in control of the switch.
class MetaAds {
  MetaAds._();

  static final FacebookAppEvents _fb = FacebookAppEvents();
  static bool _enabled = false;

  /// Mirrors Analytics.collectionEnabled: off in debug so local runs never
  /// pollute campaign attribution, overridable for verification.
  static const bool _force = bool.fromEnvironment('FORCE_TELEMETRY');
  static bool get collectionEnabled => !kDebugMode || _force;

  static Future<void> init() async {
    if (!collectionEnabled) {
      debugPrint('MetaAds: collection disabled for this build');
      return;
    }
    try {
      // The only real runtime switch on Android. Advertiser id collection is
      // controlled by the manifest, since the plugin's setAdvertiserTracking
      // is a no op here and only matters for iOS ATT later.
      await _fb.setAutoLogAppEventsEnabled(true);
      await _fb.setAdvertiserTracking(enabled: true);
      _enabled = true;
    } catch (e) {
      debugPrint('MetaAds: init failed, continuing without it: $e');
      _enabled = false;
    }
  }

  static Future<void> _log(String name, [Map<String, dynamic>? params]) async {
    if (!_enabled) return;
    try {
      await _fb.logEvent(name: name, parameters: params);
    } catch (e) {
      debugPrint('MetaAds: $name failed: $e');
    }
  }

  /// Someone created an account. Meta's standard registration event, and the
  /// usual optimisation target for an app install campaign.
  static Future<void> completedRegistration(String method) async {
    if (!_enabled) return;
    try {
      await _fb.logCompletedRegistration(registrationMethod: method);
    } catch (e) {
      debugPrint('MetaAds: completedRegistration failed: $e');
    }
  }

  /// First real use of the product. This is the activation signal worth
  /// optimising towards, because an install that never imports is worthless.
  static Future<void> firstImportCompleted(String source) =>
      _log('fb_mobile_achievement_unlocked', {
        'fb_description': 'first_recipe_import',
        'source': source,
      });

  static Future<void> recipeImported(String source) =>
      _log('recipe_imported', {'source': source});

  /// Reached the paywall. Meta's initiated checkout equivalent, useful as a
  /// mid funnel optimisation event while purchase volume is still low.
  static Future<void> initiatedCheckout() async {
    if (!_enabled) return;
    try {
      await _fb.logInitiatedCheckout();
    } catch (e) {
      debugPrint('MetaAds: initiatedCheckout failed: $e');
    }
  }

  /// A subscription started. Meta's dedicated subscription event, which is
  /// what campaigns ultimately optimise on. Also logs a purchase so value
  /// based bidding has an amount to work with.
  /// [price] and [currency] may be null when the product could not be
  /// resolved. The conversion is still reported, just without a value, which
  /// is better than reporting a misleading zero into value based bidding.
  static Future<void> subscribed({
    required String orderId,
    double? price,
    String? currency,
    bool isTrial = false,
  }) async {
    if (!_enabled) return;
    try {
      if (isTrial) {
        await _fb.logStartTrial(
            price: price, currency: currency, orderId: orderId);
      } else {
        await _fb.logSubscribe(
            price: price, currency: currency, orderId: orderId);
      }
      if (price != null && currency != null) {
        // Meta's setup checklist requires Content ID, Content Type, Currency
        // and ValueToSum on Purchase. Currency and value are named arguments;
        // the other two go in parameters.
        await _fb.logPurchase(
          amount: price,
          currency: currency,
          parameters: {
            FacebookAppEvents.paramNameContentId: orderId,
            FacebookAppEvents.paramNameContentType: 'subscription',
          },
        );
      }
    } catch (e) {
      debugPrint('MetaAds: subscribe failed: $e');
    }
  }

  /// Clear the advertising identifiers Meta holds for this device on sign out.
  static Future<void> clear() async {
    if (!_enabled) return;
    try {
      await _fb.clearUserData();
      await _fb.clearUserID();
    } catch (e) {
      debugPrint('MetaAds: clear failed: $e');
    }
  }
}
