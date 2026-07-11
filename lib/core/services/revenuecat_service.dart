import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Central wrapper around the RevenueCat (purchases_flutter) SDK.
///
/// Responsibilities:
///  - configure the SDK at startup with the correct platform key
///  - identify / log out the user so purchases follow the Supabase account
///  - expose a broadcast stream of [CustomerInfo] so the app reacts to
///    purchases, restores, renewals and expirations in real time
///  - answer "is the user Plateful Pro?" via entitlement checking
class RevenueCatService {
  RevenueCatService._();
  static final RevenueCatService instance = RevenueCatService._();

  /// The entitlement identifier configured in the RevenueCat dashboard.
  static const String entitlementId = 'Plateful Pro';

  /// The offering identifier (defaults to "current" if you only have one).
  static const String offeringId = 'default';

  final ValueNotifier<CustomerInfo?> customerInfo =
      ValueNotifier<CustomerInfo?>(null);

  bool _configured = false;

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
  /// Safe to call when no usable key is present — it no-ops so the app runs
  /// normally (just without in-app purchases).
  Future<void> configure() async {
    if (_configured) return;
    final key = _apiKey;
    if (!_isUsableKey(key)) {
      debugPrint(
          'RevenueCat: no usable key for this build, skipping configure');
      return;
    }

    // Verbose logs in debug only.
    await Purchases.setLogLevel(
        kDebugMode ? LogLevel.debug : LogLevel.warn);

    await Purchases.configure(PurchasesConfiguration(key!));
    _configured = true;

    // Seed + subscribe to live updates.
    try {
      customerInfo.value = await Purchases.getCustomerInfo();
    } catch (e) {
      debugPrint('RevenueCat: initial getCustomerInfo failed: $e');
    }
    Purchases.addCustomerInfoUpdateListener((info) {
      customerInfo.value = info;
    });
  }

  /// Tie RevenueCat purchases to a stable app user id (the Supabase user id),
  /// so entitlements follow the account across devices.
  Future<void> identify(String appUserId) async {
    if (!_configured) return;
    try {
      final result = await Purchases.logIn(appUserId);
      customerInfo.value = result.customerInfo;
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
      customerInfo.value = await Purchases.logOut();
    } catch (e) {
      // Never let a billing/SDK error crash sign-out.
      debugPrint('RevenueCat: logOut failed (ignored): $e');
    }
  }

  // ── Entitlement checking ─────────────────────────────────────────────────
  bool isProFrom(CustomerInfo? info) =>
      info?.entitlements.active.containsKey(entitlementId) ?? false;

  bool get isPro => isProFrom(customerInfo.value);

  /// Fetch the current offering (set of products to display).
  Future<Offering?> currentOffering() async {
    if (!_configured) return null;
    try {
      final offerings = await Purchases.getOfferings();
      return offerings.getOffering(offeringId) ?? offerings.current;
    } catch (e) {
      debugPrint('RevenueCat: getOfferings failed: $e');
      return null;
    }
  }

  /// Purchase a specific package. Returns true if Plateful Pro is now active.
  /// Throws nothing — surfaces a [PurchaseResult] for the UI to handle.
  Future<PurchaseResult> purchase(Package package) async {
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
        return PurchaseResult(success: false, cancelled: true);
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
      customerInfo.value = await Purchases.getCustomerInfo();
    } catch (e) {
      debugPrint('RevenueCat: refresh failed: $e');
    }
  }

  /// Restore previous purchases (required by App Store / Play guidelines).
  Future<PurchaseResult> restore() async {
    try {
      final info = await Purchases.restorePurchases();
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
        return 'Network error — please check your connection and try again.';
      case PurchasesErrorCode.purchaseNotAllowedError:
        return 'Purchases are not allowed on this device.';
      case PurchasesErrorCode.paymentPendingError:
        return 'Your payment is pending. We\'ll unlock Pro once it clears.';
      case PurchasesErrorCode.productAlreadyPurchasedError:
        return 'You already own this — try Restore Purchases.';
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
