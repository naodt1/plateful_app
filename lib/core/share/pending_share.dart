/// Holds a recipe link shared into the app from a *cold start*, so the splash
/// screen can route to the import flow only after it has finished navigating.
///
/// Without this, the splash's post-animation `go('/home')` clobbers the import
/// screen that the share intent pushed on top of it — the parse keeps running
/// in the background and the user lands on home having to refresh to see the
/// new recipe. See [SplashScreen] for where this gets consumed.
class PendingShare {
  PendingShare._();

  static String? _url;

  /// Stash a shared URL received before the app has finished launching.
  static void set(String url) => _url = url;

  /// Whether a cold-start share is waiting to be handled.
  static bool get has => _url != null;

  /// Returns the pending URL (if any) and clears it so it's consumed once.
  static String? take() {
    final url = _url;
    _url = null;
    return url;
  }
}
