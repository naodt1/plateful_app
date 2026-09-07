import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Creator referral codes, used to attribute signups and revenue to the UGC
/// creator who sent the user.
///
/// A code is captured during onboarding, held locally until the account exists,
/// then written to the profile and pushed to RevenueCat as a subscriber
/// attribute. That last part is what makes revenue sliceable by creator at
/// payout time, rather than only counting signups.
class ReferralService {
  ReferralService._();

  static const String _pendingKey = 'pending_referral_code';

  /// Codes are shown on screen and read aloud in videos, so they are stored
  /// uppercase and stripped of the punctuation people add by habit.
  static String? normalise(String? raw) {
    if (raw == null) return null;
    final cleaned =
        raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '').trim();
    if (cleaned.length < 3 || cleaned.length > 20) return null;
    return cleaned;
  }

  /// Hold a code entered before the account exists. Onboarding collects it
  /// before signup, so it cannot be written to a profile yet.
  static Future<bool> setPending(String raw) async {
    final code = normalise(raw);
    if (code == null) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingKey, code);
      return true;
    } catch (e) {
      debugPrint('Referral: could not stash code: $e');
      return false;
    }
  }

  static Future<String?> pending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_pendingKey);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearPending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingKey);
    } catch (_) {/* nothing to clean up */}
  }

  /// Tell RevenueCat which creator this customer came from, so their dashboard
  /// can break subscriptions and revenue down by code. Safe to call more than
  /// once; it overwrites rather than duplicating.
  static Future<void> attachToRevenueCat(String code) async {
    try {
      await Purchases.setAttributes({'referral_code': code});
      // Also fill the campaign field RevenueCat reports on natively.
      await Purchases.setCampaign(code);
      await Purchases.setMediaSource('ugc_creator');
    } catch (e) {
      // Billing being unavailable must never block a signup.
      debugPrint('Referral: could not attach to RevenueCat: $e');
    }
  }
}
