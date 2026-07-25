import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/firebase_service.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/share/pending_share.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  late final Animation<double> _taglineOpacity;

  @override
  void initState() {
    super.initState();

    // Force status bar to be transparent / light-on-dark for the green bg
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // Logo: gentle scale-up + fade-in
    _scale = Tween<double>(begin: 0.72, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.75, curve: Curves.easeOutBack),
      ),
    );

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
      ),
    );

    // Tagline fades in slightly after the logo settles
    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.forward();

    // A share launched the app: the user is waiting on their recipe, so skip
    // the splash entirely. Otherwise hold just long enough to read the logo.
    if (PendingShare.has) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _navigate());
    } else {
      Timer(const Duration(milliseconds: 1200), _navigate);
    }
  }

  void _navigate() {
    if (!mounted) return;
    if (FirebaseService.currentUserId != null) {
      // Home first so back from the import lands somewhere sensible, then the
      // import on top — both happen in the same frame, so nothing flashes.
      context.go('/home');
      final sharedUrl = PendingShare.take();
      if (sharedUrl != null) {
        context.push('/recipe/import', extra: {'url': sharedUrl});
      }
    } else {
      // Not signed in: leave any pending share queued for after sign-in.
      context.go('/onboarding');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Logo ──────────────────────────────────────────────────
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Opacity(
                    opacity: _opacity.value,
                    child: Transform.scale(
                      scale: _scale.value,
                      child: child,
                    ),
                  );
                },
                child: Image.asset(
                  'assets/images/play_store_512.png',
                  width: 160,
                  height: 160,
                ),
              ),

              const SizedBox(height: 28),

              // ── App name ──────────────────────────────────────────────
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) => Opacity(
                  opacity: _taglineOpacity.value,
                  child: child,
                ),
                child: Text(
                  'Plateful',
                  style: AppTextStyles.displayLarge.copyWith(
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // ── Tagline ───────────────────────────────────────────────
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) => Opacity(
                  opacity: _taglineOpacity.value,
                  child: child,
                ),
                child: Text(
                  'Your kitchen, your recipes',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
