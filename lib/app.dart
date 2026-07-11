import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'core/router/app_router.dart';
import 'core/services/revenuecat_service.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/theme_provider.dart';
import 'core/share/pending_share.dart';

class PlatefulApp extends ConsumerStatefulWidget {
  const PlatefulApp({super.key});

  @override
  ConsumerState<PlatefulApp> createState() => _PlatefulAppState();
}

class _PlatefulAppState extends ConsumerState<PlatefulApp>
    with WidgetsBindingObserver {
  StreamSubscription<List<SharedMediaFile>>? _intentSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Load persisted theme preference
    Future.microtask(() => ref.read(themeModeProvider.notifier).init());
    _initShareIntent();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check subscription state whenever the app returns to the foreground,
    // so a purchase/renewal/restore completed elsewhere unlocks Pro features
    // without needing a cold restart.
    if (state == AppLifecycleState.resumed) {
      RevenueCatService.instance.refresh();
    }
  }

  void _initShareIntent() {
    // Shares received while the app is already running (warm start)
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (files) {
        _handleSharedFiles(files);
        ReceiveSharingIntent.instance.reset();
      },
      onError: (err) {
        // Ignore — plugin may emit errors on platforms where sharing is unavailable.
        debugPrint('[ShareIntent] stream error: $err');
      },
    );

    // Share that launched the app from a cold start. Stash it and let the
    // splash screen route to the import flow *after* it navigates — otherwise
    // the splash's go('/home') clobbers an import screen pushed here and the
    // parse finishes invisibly in the background.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final files = await ReceiveSharingIntent.instance.getInitialMedia();
        final shared = _extractSharedUrl(files);
        if (shared != null) {
          PendingShare.set(shared);
          ReceiveSharingIntent.instance.reset();
        }
      } catch (e) {
        debugPrint('[ShareIntent] getInitialMedia error: $e');
      }
    });
  }

  /// Pull the first text/url payload out of a share (Instagram, TikTok,
  /// YouTube and browsers all share a link). Returns null if there's nothing.
  String? _extractSharedUrl(List<SharedMediaFile> files) {
    if (files.isEmpty) return null;
    String? shared;
    for (final f in files) {
      if (f.type == SharedMediaType.text || f.type == SharedMediaType.url) {
        shared = f.path;
        break;
      }
    }
    shared ??= files.first.path;
    return shared.trim().isEmpty ? null : shared;
  }

  void _handleSharedFiles(List<SharedMediaFile> files) {
    final shared = _extractSharedUrl(files);
    if (shared == null) return;

    // Warm start: the shell is already mounted, so push the import flow
    // straight away. addPostFrameCallback keeps us safely past the build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        AppRouter.router.push('/recipe/import', extra: {'url': shared});
      } catch (e) {
        debugPrint('[ShareIntent] router push error: $e');
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _intentSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Plateful',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: AppRouter.router,
      debugShowCheckedModeBanner: false,
    );
  }
}
