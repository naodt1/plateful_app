import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';
import '../services/claude_service.dart';

/// Converts any thrown error into a short, user-friendly message.
///
/// Never returns raw exception text or Firebase error codes — use this anywhere
/// an error is shown to the user (SnackBars, error states, inline banners).
String friendlyError(Object e) {
  // Auth: reuse the shared auth mapper (cancellation -> generic here).
  if (e is FirebaseAuthException) {
    return FirebaseService.authErrorMessage(e) ??
        'Something went wrong. Please try again.';
  }

  // Recipe import already carries a human-readable reason.
  if (e is NoRecipeFoundException) return e.reason;

  if (e is TimeoutException) {
    return 'This is taking longer than usual. Check your connection and try again.';
  }

  // Firestore / other Firebase plugin errors.
  if (e is FirebaseException) {
    switch (e.code) {
      case 'permission-denied':
        return 'You don\'t have permission to do that.';
      case 'unavailable':
      case 'internal':
        return 'The service is temporarily unavailable. Please try again.';
      case 'not-found':
        return 'We couldn\'t find that.';
      case 'deadline-exceeded':
        return 'That took too long. Please try again.';
      case 'unauthenticated':
        return 'Please sign in again to continue.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  // Network hints from http / dart:io style errors.
  final s = e.toString();
  if (s.contains('SocketException') ||
      s.contains('Failed host lookup') ||
      s.contains('Connection refused') ||
      s.contains('Network is unreachable') ||
      s.contains('ClientException')) {
    return 'No connection. Check your internet and try again.';
  }

  return 'Something went wrong. Please try again.';
}
