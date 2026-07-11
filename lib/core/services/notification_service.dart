import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'revenuecat_service.dart';

/// Local notifications, currently used for the "your free trial ends soon"
/// reminder. The reminder is scheduled from RevenueCat's real entitlement
/// expiry (not a hardcoded date), fired two days before the trial ends, and is
/// kept in sync as the subscription state changes.
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int _trialReminderId = 1001;
  static const int _remindDaysBeforeEnd = 2;
  static bool _ready = false;

  /// Initialise the plugin + timezone database. Call once at startup.
  static Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      final dynamic info = await FlutterTimezone.getLocalTimezone();
      // flutter_timezone returns a String on some versions and a
      // TimezoneInfo (with .identifier) on others — handle both.
      final name = info is String ? info : info?.identifier as String?;
      if (name != null) tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // Falls back to UTC; only shifts the reminder by a few hours.
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: darwin),
    );
    _ready = true;
  }

  /// Ask the OS for permission to post notifications. Best to call this in a
  /// contextual moment (e.g. right after the user starts their trial).
  static Future<void> requestPermissions() async {
    if (!_ready) return;
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Schedule / refresh / cancel the trial reminder based on the current
  /// RevenueCat [CustomerInfo]. Idempotent: a fixed notification id means
  /// repeat calls replace any existing reminder rather than stacking.
  static Future<void> syncTrialReminder(CustomerInfo? info) async {
    if (!_ready) return;

    final ent = info?.entitlements.active[RevenueCatService.entitlementId];
    final inTrial = ent != null && ent.periodType == PeriodType.trial;
    final expiry =
        ent?.expirationDate != null ? DateTime.tryParse(ent!.expirationDate!) : null;

    // Only remind during an active trial with a known, future expiry.
    if (!inTrial || expiry == null) {
      await _cancel();
      return;
    }

    final fireAt = expiry.subtract(const Duration(days: _remindDaysBeforeEnd));
    if (fireAt.isBefore(DateTime.now().add(const Duration(minutes: 1)))) {
      // Too late to give two days' notice; don't fire a misleading reminder.
      await _cancel();
      return;
    }

    try {
      await _plugin.zonedSchedule(
        _trialReminderId,
        'Your Plateful Pro trial ends soon',
        'Heads up: your free trial ends in 2 days. Keep unlimited imports, Healthify and Tailor by staying Pro.',
        tz.TZDateTime.from(fireAt, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'trial_reminders',
            'Trial reminders',
            channelDescription: 'Reminds you before your free trial ends',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('NotificationService: schedule failed (ignored): $e');
    }
  }

  static Future<void> _cancel() async {
    try {
      await _plugin.cancel(_trialReminderId);
    } catch (_) {}
  }
}
