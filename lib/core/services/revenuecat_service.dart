import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Central wrapper around the RevenueCat (purchases_flutter) SDK.
///
/// Responsibilities:
///  - configure the SDK at startup with the correct platform key
///  - identify / log out the user so purchases follow the Firebase account
///  - expose a broadcast stream of [CustomerInfo] so the app reacts to
///    purchases, restores, renewals and expirations in real time
///  - answer "is the user Plateful Pro?" via entitlement checking
///
/// Every method here is failure tolerant on purpose. Billing is the one
/// subsystem that is routinely unreachable (offline, Play Services missing,
/// dashboard mid change) and none of those states may crash the app, block
/// startup, or permanently lock a user out of features they paid for.
class RevenueCatService {
  RevenueCatService._();
  static final RevenueCatService instance = RevenueCatService._();

  /// The entitlement identifier configured in the RevenueCat dashboard.
  /// Used when an id must be named. Entitlement *checking* deliberately does
  /// not depend on it, see [isProFrom].
  static const String entitlementId = 'Plateful Pro';

  /// The offering identifier (falls back to `current` if this is absent).
  static const String offeringId = 'default';

  static const Duration _netTimeout = Duration(seconds: 10);

  final ValueNotifier<CustomerInfo?> customerInfo =
      ValueNotifier<CustomerInfo?>(null);

  bool _configured = false;
  bool _configuring = false;

  /// Whether the SDK configured successfully with a usable key.
  bool get isConfigured => _configured;

  String? get _apiKey {
    if (kIsWeb) return null;
    if (Platform.isAndroid) {
      // In release builds use the real Play Store key (goog_...). A test_ key
      // makes the RevenueCat SDK intentionally crash release builds, so we
      // only fall back to it in debug.
      final prod = dotenv.env['REVENUECAT_ANDROID_API_KEY'];
      final dev = dotenv.env['REVENUECAT_ANDROID_TEST_KEY'] ?? prod;
      return kReleaseMode ? prod : dev;
    }
    if (Platform.isIOS || Platform.isMacOS) {
      return dotenv.env['REVENUECAT_IOS_API_KEY'];
    }
    return null;
  }

  /// Whether a key is safe to configure with in the current build mode.
  /// - test_ keys are allowed ONLY in debug (they crash release builds).
  /// - placeholder keys (REPLACE...) are never valid.
  /// - any other non-empty key is treated as a real key.
  bool _isUsableKey(String? key) {
    if (key == null || key.isEmpty) return false;
    if (key.contains('REPLACE')) return false; // placeholder, not set yet
    if (key.startsWith('test_') && kReleaseMode) return false; // crashes release
    return true;
  }

  /// Configure the SDK. Call once during app startup, before runApp.
  ///
  /// Never throws and never blocks on the network. A failure here leaves the
  /// service unconfigured so [ensureConfigured] can retry later, rather than
  /// disabling purchases for the rest of the session.
  Future<void> configure() async {
    if (_configured || _configuring) return;
    _configuring = true;
    try {
      final key = _apiKey;
      if (!_isUsableKey(key)) {
        debugPrint(
            'RevenueCat: no usable key for this build, skipping configure');
        return;
      }

      // Verbose logs in debug only.
      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.warn);
      await Purchases.configure(PurchasesConfiguration(key!));
      _configured = true;

      Purchases.addCustomerInfoUpdateListener((info) {
        customerInfo.value = info;
      });
    } catch (e) {
      // A throw from configure used to propagate into main() and take the app
      // down before runApp. Purchases simply stay unavailable instead.
      debugPrint('RevenueCat: configure failed, purchases unavailable: $e');
    } finally {
      _configuring = false;
    }

    // Seed entitlement state in the background so a slow or offline network
    // cannot hold up the first frame.
    if (_configured) unawaited(refresh());
  }

  /// Configure on demand if startup configuration did not succeed. Cheap when
  /// already configured, so it is safe to call before any billing operation.
  Future<bool> ensureConfigured() async {
    if (_configured) return true;
    await configure();
    return _configured;
  }

  /// Tie RevenueCat purchases to a stable app user id (the Firebase user id),
  /// so entitlements follow the account across devices.
  Future<void> identify(String appUserId) async {
    if (!await ensureConfigured()) return;
    try {
      final result =
          await Purchases.logIn(appUserId).timeout(_netTimeout);
      customerInfo.value = result.customerInfo;

      // Onboarding shows the paywall before signup, so a purchase can land on
      // an anonymous app user id. Whether it follows the user into their real
      // account depends on a RevenueCat dashboard transfer setting, and when
      // that is not set to transfer the customer is left paying without Pro.
      //
      // The entitlement lives on their Google Play account either way, so a
      // restore reclaims it. Only attempted when they are not already Pro, so
      // the normal path costs nothing.
      if (!isPro) {
        debugPrint('RevenueCat: signed in without Pro, attempting restore in '
            'case the purchase is still on an anonymous id');
        final info =
            await Purchases.restorePurchases().timeout(_netTimeout);
        customerInfo.value = info;
        if (isPro) {
          debugPrint('RevenueCat: restore recovered an entitlement');
        }
      }
    } catch (e) {
      debugPrint('RevenueCat: logIn failed: $e');
    }
  }

  /// Detach the identified user (call on sign-out).
  /// No-ops if the SDK user is already anonymous — calling logOut() on an
  /// anonymous user throws in the RevenueCat SDK.
  Future<void> logOut() async {
    if (!_configured) return;
    try {
      final isAnonymous = await Purchases.isAnonymous;
      if (isAnonymous) return; // nothing to log out
      customerInfo.value = await Purchases.logOut().timeout(_netTimeout);
    } catch (e) {
      // Never let a billing/SDK error crash sign-out.
      debugPrint('RevenueCat: logOut failed (ignored): $e');
    }
  }

  // ── Entitlement checking ─────────────────────────────────────────────────
  /// True when the customer holds any active entitlement.
  ///
  /// This deliberately does not require an exact match on [entitlementId].
  /// Dashboard identifiers get renamed, re-cased and re-spaced during setup,
  /// and an exact match means one drifted character silently locks a paying
  /// customer out of what they just bought. Plateful sells a single
  /// subscription, so any active entitlement means Pro.
  bool isProFrom(CustomerInfo? info) {
    final active = info?.entitlements.active;
    if (active == null || active.isEmpty) return false;
    if (!active.containsKey(entitlementId)) {
      debugPrint('RevenueCat: active entitlement ${active.keys.toList()} does '
          'not match configured id "$entitlementId", honouring it anyway');
    }
    return true;
  }

  bool get isPro => isProFrom(customerInfo.value);

  DateTime? _offeringsCheckedAt;
  bool _hasSellableOffering = false;

  /// Whether a purchase could actually be completed right now: the SDK is
  /// configured and RevenueCat is returning at least one package to sell.
  ///
  /// Used to avoid showing a paywall the user has no way to clear. Cached for
  /// a few minutes because this sits on the import path.
  Future<bool> canPurchase() async {
    if (!await ensureConfigured()) return false;
    final now = DateTime.now();
    if (_offeringsCheckedAt != null &&
        now.difference(_offeringsCheckedAt!) < const Duration(minutes: 5)) {
      return _hasSellableOffering;
    }
    try {
      final offerings = await Purchases.getOfferings().timeout(_netTimeout);
      final offering = offerings.getOffering(offeringId) ?? offerings.current;
      _hasSellableOffering = offering?.availablePackages.isNotEmpty ?? false;
      if (!_hasSellableOffering) {
        debugPrint('RevenueCat: no purchasable packages in any offering');
      }
    } catch (e) {
      debugPrint('RevenueCat: offerings check failed: $e');
      _hasSellableOffering = false;
    }
    _offeringsCheckedAt = now;
    return _hasSellableOffering;
  }

  /// Drop the cached offerings answer so the next [canPurchase] re-checks.
  void invalidateOfferingsCache() => _offeringsCheckedAt = null;

  /// Fetch the current offering (set of products to display).
  Future<Offering?> currentOffering() async {
    if (!await ensureConfigured()) return null;
    try {
      final offerings = await Purchases.getOfferings().timeout(_netTimeout);
      return offerings.getOffering(offeringId) ?? offerings.current;
    } catch (e) {
      debugPrint('RevenueCat: getOfferings failed: $e');
      return null;
    }
  }

  /// Purchase a specific package. Returns true if Plateful Pro is now active.
  /// Throws nothing — surfaces a [PurchaseResult] for the UI to handle.
  Future<PurchaseResult> purchase(Package package) async {
    if (!await ensureConfigured()) {
      return const PurchaseResult(
        success: false,
        error: 'Purchases are unavailable on this device right now.',
      );
    }
    try {
      final result = await Purchases.purchasePackage(package);
      customerInfo.value = result.customerInfo;
      return PurchaseResult(
        success: isProFrom(result.customerInfo),
        customerInfo: result.customerInfo,
      );
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return const PurchaseResult(success: false, cancelled: true);
      }
      return PurchaseResult(success: false, error: _messageFor(code));
    } catch (e) {
      return PurchaseResult(success: false, error: e.toString());
    }
  }

  /// Pull the latest [CustomerInfo] from RevenueCat and publish it, so feature
  /// gating reacts to entitlements that became active out-of-band — a renewal,
  /// a purchase made on another device, or a dashboard/product mapping change.
  /// Safe to call often; no-ops if the SDK isn't configured.
  Future<void> refresh() async {
    if (!_configured) return;
    try {
      customerInfo.value =
          await Purchases.getCustomerInfo().timeout(_netTimeout);
    } catch (e) {
      debugPrint('RevenueCat: refresh failed: $e');
    }
  }

  /// Price and currency of whatever the customer is currently subscribed to,
  /// resolved by matching their active subscription against the offering's
  /// products. Returns null when it cannot be determined, so callers can
  /// report a conversion without inventing a value.
  /// True when the active entitlement is currently in its free trial period.
  /// Meta treats StartTrial and Subscribe as different conversions, so
  /// reporting the wrong one skews campaign optimisation.
  bool get isInTrial {
    try {
      final active = customerInfo.value?.entitlements.active.values;
      if (active == null || active.isEmpty) return false;
      return active.any((e) => e.periodType == PeriodType.trial);
    } catch (_) {
      return false;
    }
  }

  Future<({double price, String currency, String productId})?>
      activeSubscriptionPrice() async {
    try {
      final info = customerInfo.value;
      final active = info?.activeSubscriptions ?? const <String>[];
      if (active.isEmpty) return null;
      final offering = await currentOffering();
      if (offering == null) return null;
      for (final pkg in offering.availablePackages) {
        final p = pkg.storeProduct;
        // Play appends the base plan id, so match on prefix as well as equality.
        final hit = active.any((a) =>
            a == p.identifier || a.startsWith('\${p.identifier}:'));
        if (hit) {
          return (
            price: p.price,
            currency: p.currencyCode,
            productId: p.identifier
          );
        }
      }
      return null;
    } catch (e) {
      debugPrint('RevenueCat: could not resolve subscription price: \$e');
      return null;
    }
  }

  /// Restore previous purchases (required by App Store / Play guidelines, and
  /// the recovery path when an entitlement is not being detected).
  Future<PurchaseResult> restore() async {
    if (!await ensureConfigured()) {
      return const PurchaseResult(
        success: false,
        error: 'Purchases are unavailable on this device right now.',
      );
    }
    try {
      final info =
          await Purchases.restorePurchases().timeout(_netTimeout);
      customerInfo.value = info;
      return PurchaseResult(success: isProFrom(info), customerInfo: info);
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      return PurchaseResult(success: false, error: _messageFor(code));
    } catch (e) {
      return PurchaseResult(success: false, error: e.toString());
    }
  }

  String _messageFor(PurchasesErrorCode code) {
    switch (code) {
      case PurchasesErrorCode.networkError:
        return 'Network error. Check your connection and try again.';
      case PurchasesErrorCode.purchaseNotAllowedError:
        return 'Purchases are not allowed on this device.';
      case PurchasesErrorCode.paymentPendingError:
        return 'Your payment is pending. Pro unlocks once it clears.';
      case PurchasesErrorCode.productAlreadyPurchasedError:
        return 'You already own this. Try Restore Purchases.';
      case PurchasesErrorCode.storeProblemError:
        return 'The Play Store is having trouble. Please try again shortly.';
      case PurchasesErrorCode.configurationError:
        return 'Subscriptions are not set up correctly yet. Please try later.';
      default:
        return 'Something went wrong with the purchase. Please try again.';
    }
  }
}

class PurchaseResult {
  final bool success;
  final bool cancelled;
  final String? error;
  final CustomerInfo? customerInfo;

  const PurchaseResult({
    required this.success,
    this.cancelled = false,
    this.error,
    this.customerInfo,
  });
}
