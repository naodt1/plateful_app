import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app.dart';
import 'firebase_options.dart';
import 'core/services/firebase_service.dart';
import 'core/services/revenuecat_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/analytics_service.dart';
import 'core/services/meta_ads_service.dart';
import 'core/share/pending_share.dart';

void main() async {
  // runZonedGuarded catches async errors that escape the framework; the two
  // handlers below catch framework and platform errors. Together they are what
  // makes Crashlytics see everything rather than only widget build failures.
  runZonedGuarded(() async {
    await _bootstrap();
  }, (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
}

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env file (optional in production; also holds the Supabase URL/anon key
  // still used by the AI edge functions in claude_service).
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env may not exist in production; use dart-define instead.
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Crash reporting first, so anything that fails later in startup is captured.
  // Off in debug so local experiments do not pollute production crash rates.
  await FirebaseCrashlytics.instance
      .setCrashlyticsCollectionEnabled(Analytics.collectionEnabled);
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  await Analytics.init();
  await MetaAds.init();

  // Local notifications (used for the trial-ending reminder).
  await NotificationService.init();

  // Configure RevenueCat, then tie purchases to the signed-in account.
  // Bounded and guarded: billing must never delay or prevent startup. If this
  // does not finish in time the SDK reconfigures on demand the first time a
  // billing operation is actually needed.
  try {
    await RevenueCatService.instance
        .configure()
        .timeout(const Duration(seconds: 6));
    final userId = FirebaseService.currentUserId;
    if (userId != null) {
      await RevenueCatService.instance
          .identify(userId)
          .timeout(const Duration(seconds: 6));
    }
  } catch (e) {
    debugPrint('RevenueCat startup skipped, will configure on demand: $e');
  }

  // Keep the "trial ends in 2 days" reminder in sync with the real
  // subscription state: schedule it when a trial is active, cancel otherwise.
  NotificationService.syncTrialReminder(
      RevenueCatService.instance.customerInfo.value);
  RevenueCatService.instance.customerInfo.addListener(() {
    NotificationService.syncTrialReminder(
        RevenueCatService.instance.customerInfo.value);
  });

  // Keep RevenueCat's user in sync with Firebase auth changes.
  // Wrapped so a billing/SDK hiccup can never crash auth transitions.
  FirebaseAuth.instance.authStateChanges().listen((user) {
    Analytics.setUser(user?.uid);
    if (user != null) {
      RevenueCatService.instance.identify(user.uid);
    } else {
      RevenueCatService.instance.logOut();
      MetaAds.clear();
    }
  }, onError: (e) {
    debugPrint('Auth state listener error (ignored): $e');
  });

  // Resolve a share that launched the app *before* the first frame, so the
  // splash can skip its animation and go straight to the import. Bounded so a
  // slow platform channel can never hold up startup.
  try {
    final files = await ReceiveSharingIntent.instance
        .getInitialMedia()
        .timeout(const Duration(milliseconds: 700));
    for (final f in files) {
      if (f.type == SharedMediaType.text || f.type == SharedMediaType.url) {
        if (f.path.trim().isNotEmpty) PendingShare.set(f.path);
        break;
      }
    }
    if (files.isNotEmpty && !PendingShare.has) {
      if (files.first.path.trim().isNotEmpty) PendingShare.set(files.first.path);
    }
    if (PendingShare.has) ReceiveSharingIntent.instance.reset();
  } catch (e) {
    debugPrint('Initial share lookup skipped: $e');
  }

  runApp(
    const ProviderScope(
      child: PlatefulApp(),
    ),
  );
}
