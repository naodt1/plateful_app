import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/airbnb_button.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(context).bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Spacer(),
              // Illustration placeholder
              Container(
                width: double.infinity,
                height: 280,
                decoration: BoxDecoration(
                  color: AppColors.of(context).surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.of(context).border),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      top: 32,
                      right: 40,
                      child: _FoodCircle(size: 64, emoji: '🥗'),
                    ),
                    Positioned(
                      top: 60,
                      left: 30,
                      child: _FoodCircle(size: 48, emoji: '🍜'),
                    ),
                    Positioned(
                      bottom: 50,
                      right: 60,
                      child: _FoodCircle(size: 56, emoji: '🍕'),
                    ),
                    Positioned(
                      bottom: 40,
                      left: 40,
                      child: _FoodCircle(size: 52, emoji: '🥘'),
                    ),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.restaurant_menu, size: 40, color: Colors.white),
                    ),
                  ],
                ),
              ).animate().scale(duration: 400.ms, curve: Curves.easeOut),
              const SizedBox(height: 48),
              Text(
                'Plateful',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ).animate().fadeIn(delay: 100.ms),
              const SizedBox(height: 12),
              Text(
                'Every recipe you love,\nalways within reach.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w400,
                  color: AppColors.of(context).textSecondary,
                  height: 1.5,
                ),
              ).animate().fadeIn(delay: 200.ms),
              const Spacer(),
              AirbnbButton(
                label: 'Get Started',
                onPressed: () => context.push('/onboarding/diet'),
              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.3, end: 0),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => context.push('/signup'),
                child: Text(
                  'Already have an account? Sign in',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ).animate().fadeIn(delay: 350.ms),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _FoodCircle extends StatelessWidget {
  final double size;
  final String emoji;

  const _FoodCircle({required this.size, required this.emoji});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(emoji, style: TextStyle(fontSize: size * 0.5)),
      ),
    );
  }
}
