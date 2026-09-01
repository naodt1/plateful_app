import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Product analytics for Plateful.
///
/// Deliberately a small, typed event set rather than logging everything. Each
/// event answers a question we actually need answered about the funnel:
/// does an install become a signup, does a signup become a first import, does
/// an import succeed, and does anyone reach or clear the paywall.
///
/// Every method here is failure tolerant. Analytics must never break a user
/// flow, so nothing throws and nothing blocks.
class Analytics {
  Analytics._();

  static FirebaseAnalytics? _fa;
  static bool _enabled = false;

  /// Debug builds report nothing so local runs stay out of production funnels.
  /// Pass --dart-define=FORCE_TELEMETRY=true to verify the pipeline end to end
  /// from a debug build without changing that default.
  static const bool _force = bool.fromEnvironment('FORCE_TELEMETRY');
  static bool get collectionEnabled => !kDebugMode || _force;

  /// Wire up once at startup, after Firebase.initializeApp.
  static Future<void> init() async {
    try {
      _fa = FirebaseAnalytics.instance;
      // Debug builds would otherwise pollute production funnels.
      await _fa!.setAnalyticsCollectionEnabled(collectionEnabled);
      _enabled = true;
    } catch (e) {
      debugPrint('Analytics: init failed, continuing without it: $e');
      _enabled = false;
    }
  }

  static Future<void> _log(String name, [Map<String, Object>? params]) async {
    if (!_enabled || _fa == null) return;
    try {
      await _fa!.logEvent(name: name, parameters: params);
    } catch (e) {
      debugPrint('Analytics: $name failed: $e');
    }
  }

  /// Ties events and crash reports to a user so funnels can be followed across
  /// sessions. Call on sign in, and with null on sign out.
  static Future<void> setUser(String? userId) async {
    try {
      await _fa?.setUserId(id: userId);
      await FirebaseCrashlytics.instance.setUserIdentifier(userId ?? '');
    } catch (e) {
      debugPrint('Analytics: setUser failed: $e');
    }
  }

  // ── Activation ───────────────────────────────────────────────────────────
  static Future<void> signUp(String method) =>
      _log('sign_up', {'method': method});

  static Future<void> login(String method) =>
      _log('login', {'method': method});

  // ── The core loop ────────────────────────────────────────────────────────
  /// [source] is where the link came from: tiktok, instagram, youtube, website.
  /// [entry] is how the user started it: share_sheet or paste.
  static Future<void> importStarted({
    required String source,
    required String entry,
  }) =>
      _log('recipe_import_started', {'source': source, 'entry': entry});

  static Future<void> importSucceeded({
    required String source,
    required int ingredients,
    required int steps,
    required int seconds,
  }) =>
      _log('recipe_import_succeeded', {
        'source': source,
        'ingredient_count': ingredients,
        'step_count': steps,
        'duration_seconds': seconds,
      });

  /// The most valuable event here. [reason] buckets the failure so a spike in
  /// one platform or one cause is visible without reading logs.
  static Future<void> importFailed({
    required String source,
    required String reason,
  }) =>
      _log('recipe_import_failed', {'source': source, 'reason': reason});

  // ── Feature usage ────────────────────────────────────────────────────────
  static Future<void> tailorUsed(String diet) =>
      _log('tailor_used', {'diet': diet});

  static Future<void> healthifyUsed() => _log('healthify_used');

  static Future<void> pantrySuggestUsed(int itemCount) =>
      _log('pantry_suggest_used', {'item_count': itemCount});

  static Future<void> mealPlanGenerated() => _log('meal_plan_generated');

  // ── Monetisation ─────────────────────────────────────────────────────────
  /// [trigger] is what caused it: import_limit or upgrade_tap.
  static Future<void> paywallShown(String trigger) =>
      _log('paywall_shown', {'trigger': trigger});

  static Future<void> paywallDismissed(String trigger) =>
      _log('paywall_dismissed', {'trigger': trigger});

  static Future<void> purchaseCompleted() => _log('purchase_completed');

  static Future<void> purchaseRestored() => _log('purchase_restored');

  /// Fired when the free allowance is spent but no purchase can be made, which
  /// is the trap that made the app unusable for some users.
  static Future<void> billingUnavailable() => _log('billing_unavailable');

  // ── Diagnostics ──────────────────────────────────────────────────────────
  /// Record a handled error with context. Not a crash, but worth knowing about.
  static Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? context,
  }) async {
    try {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        reason: context,
        fatal: false,
      );
    } catch (e) {
      debugPrint('Crashlytics: recordError failed: $e');
    }
  }

  /// Breadcrumb that shows up in the next crash report.
  static void breadcrumb(String message) {
    try {
      FirebaseCrashlytics.instance.log(message);
    } catch (_) {/* never let logging break a flow */}
  }
}
