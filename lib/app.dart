import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/theme_provider.dart';

class PlatefulApp extends ConsumerStatefulWidget {
  const PlatefulApp({super.key});

  @override
  ConsumerState<PlatefulApp> createState() => _PlatefulAppState();
}

class _PlatefulAppState extends ConsumerState<PlatefulApp> {
  StreamSubscription<List<SharedMediaFile>>? _intentSub;

  @override
  void initState() {
    super.initState();
    // Load persisted theme preference
    Future.microtask(() => ref.read(themeModeProvider.notifier).init());
    _initShareIntent();
  }

  void _initShareIntent() {
    // Shares received while the app is already running
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (files) {
        _handleSharedFiles(files);
        ReceiveSharingIntent.instance.reset();
      },
      onError: (_) {},
    );

    // Share that launched the app from a cold start
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      if (files.isNotEmpty) {
        _handleSharedFiles(files);
        ReceiveSharingIntent.instance.reset();
      }
    });
  }

  void _handleSharedFiles(List<SharedMediaFile> files) {
    if (files.isEmpty) return;

    // Find the first text/url payload (Instagram, TikTok, YouTube share a link)
    String? shared;
    for (final f in files) {
      if (f.type == SharedMediaType.text || f.type == SharedMediaType.url) {
        shared = f.path;
        break;
      }
    }
    shared ??= files.first.path;

    if (shared.trim().isEmpty) return;

    // Defer until the router/first frame is ready, then open the import flow
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppRouter.router.push('/recipe/import', extra: {'url': shared});
    });
  }

  @override
  void dispose() {
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
