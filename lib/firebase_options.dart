// File generated from android/app/google-services.json (Android only).
//
// iOS/macOS/web are not configured yet — run `flutterfire configure` to
// populate them. Until then, building for those platforms will throw.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'run flutterfire configure again.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for iOS - '
          'run flutterfire configure again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC3RE3jtWMIhkr_azgGR5w7R2AlvmN7aK4',
    appId: '1:42236543449:android:fc0554e02f6f3db2ab99c8',
    messagingSenderId: '42236543449',
    projectId: 'plateful-d10ff',
    storageBucket: 'plateful-d10ff.firebasestorage.app',
  );
}
