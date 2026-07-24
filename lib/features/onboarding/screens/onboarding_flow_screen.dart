import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/airbnb_button.dart';
import '../../../core/services/demo_seed_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/revenuecat_service.dart';
import '../../subscription/paywall.dart';
import '../widgets/onboarding_recipe_preview.dart';

class OnboardingFlowScreen extends StatefulWidget {
  const OnboardingFlowScreen({super.key});

  @override
  State<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends State<OnboardingFlowScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  // Steps:
  // 0 Welcome · 1 Goals · 2 Goals response · 3 Diet preferences · 4 Import
  // 5 Tutorial · 6 Demo recipe · 7 Setup progress · 8 Trial · (paywall + signup)
  static const int _lastStep = 8;

  final Set<String> _selectedGoals = {};
  String _selectedDiet = 'None';

  void _nextPage() {
    if (_currentIndex < _lastStep) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _goToPaywallThenSignup();
    }
  }

  Future<void> _goToPaywallThenSignup() async {
    // Present the RevenueCat paywall, then continue to signup regardless of
    // the result. The demo recipe is seeded after the user authenticates.
    final startedPro = await PlatefulPaywall.present(context);
    if (startedPro) {
      // Trial likely started: ask for notification permission and schedule the
      // "ends in 2 days" reminder against the real entitlement expiry.
      await NotificationService.requestPermissions();
      await NotificationService.syncTrialReminder(
          RevenueCatService.instance.customerInfo.value);
    }
    await _goToSignup();
  }

  /// "Maybe later": skip the paywall entirely and continue to signup.
  Future<void> _goToSignup() async {
    await DemoSeedService.markPending(diet: _selectedDiet);
    if (mounted) context.push('/signup', extra: {'seedDemo': true});
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Steps that show the back button + progress bar (not welcome, not the
  // full-bleed demo recipe).
  bool get _showChrome => _currentIndex > 0 && _currentIndex < 6;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(context).bg,
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (i) => setState(() => _currentIndex = i),
            children: [
              _buildWelcomeStep(), // 0
              _buildGoalsStep(), // 1
              _buildGoalsResponseStep(), // 2
              _buildDietStep(), // 3
              _buildImportSupportStep(), // 4
              _ImportTutorial(onComplete: _nextPage), // 5
              OnboardingRecipePreview(
                  onContinue: _nextPage, dietLabel: _selectedDiet), // 6
              _SetupProgressStep(
                onComplete: _nextPage,
                goals: _selectedGoals,
                diet: _selectedDiet,
              ), // 7
              _buildFreeTrialStep(), // 8
            ],
          ),
          if (_showChrome)
            Positioned(
              top: 50,
              left: 16,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new),
                onPressed: () => _pageController.previousPage(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOutCubic,
                ),
              ),
            ),
          if (_showChrome)
            Positioned(
              top: 60,
              left: 80,
              right: 80,
              child: LinearProgressIndicator(
                value: _currentIndex / 6,
                backgroundColor: AppColors.of(context).border,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primary),
                borderRadius: BorderRadius.circular(4),
                minHeight: 4,
              ).animate().fadeIn(),
            ),
        ],
      ),
    );
  }

  // ── 0 · Welcome ─────────────────────────────────────────────────────────────
  Widget _buildWelcomeStep() {
    final colors = AppColors.of(context);
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primary.withValues(alpha: 0.10),
                  colors.bg,
                  colors.bg,
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: 132,
                  height: 132,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 40,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset('assets/images/play_store_512.png',
                      fit: BoxFit.cover),
                ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack).fadeIn(),
                const SizedBox(height: 40),
                Text(
                  'Welcome to\nPlateful',
                  style: AppTextStyles.displayLarge
                      .copyWith(fontSize: 42, height: 1.1),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.12, end: 0),
                const SizedBox(height: 16),
                Text(
                  'Recipes, just the way you like them.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyLarge
                      .copyWith(color: colors.textSecondary, height: 1.5),
                ).animate().fadeIn(delay: 400.ms),
                const Spacer(),
                AirbnbButton(label: 'Get Started', onPressed: _nextPage)
                    .animate()
                    .fadeIn(delay: 600.ms)
                    .slideY(begin: 0.3, end: 0),
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: () => context.push('/login'),
                  child: RichText(
                    text: TextSpan(
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: colors.textSecondary),
                      children: const [
                        TextSpan(text: 'Already have an account? '),
                        TextSpan(
                          text: 'Sign In',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: 700.ms),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Goal label → { emoji, image, the phrase used on the response page }.
  static const String _imgCookingTime = 'assets/images/cooking_time.jpg';
  static const String _imgEatingHealthy = 'assets/images/eating_healthy.jpg';
  static const String _imgFoodWaste = 'assets/images/food_waste.jpg';

  static const List<Map<String, String>> _goals = [
    {
      'emoji': '⏱️',
      'label': 'Save time cooking',
      'img': _imgCookingTime,
      'phrase': 'save time cooking',
    },
    {
      'emoji': '🥗',
      'label': 'Eat healthier',
      'img': _imgEatingHealthy,
      'phrase': 'eat healthier',
    },
    {
      'emoji': '♻️',
      'label': 'Reduce food waste',
      'img': _imgFoodWaste,
      'phrase': 'reduce food waste',
    },
    {
      'emoji': '🍽️',
      'label': 'Tailor to my diet',
      'img': _imgEatingHealthy,
      'phrase': 'tailor recipes to your diet',
    },
    {
      'emoji': '✨',
      'label': 'Find meal inspiration',
      'img': _imgCookingTime,
      'phrase': 'find meal inspiration',
    },
    {
      'emoji': '🍱',
      'label': 'Meal prep efficiently',
      'img': _imgFoodWaste,
      'phrase': 'meal prep efficiently',
    },
  ];

  Map<String, String> get _primaryGoal => _goals.firstWhere(
        (g) => _selectedGoals.contains(g['label']),
        orElse: () => _goals.first,
      );

  // ── 1 · Goals (emoji list, max 2) ────────────────────────────────────────────
  Widget _buildGoalsStep() {
    final colors = AppColors.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 96, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('What are your goals?', style: AppTextStyles.displayMedium)
                .animate()
                .fadeIn()
                .slideX(begin: 0.1, end: 0),
            const SizedBox(height: 10),
            Text('Pick up to two and we will tailor Plateful to you.',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: colors.textSecondary))
                .animate()
                .fadeIn(delay: 100.ms),
            const SizedBox(height: 28),
            Expanded(
              child: ListView.separated(
                itemCount: _goals.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final goal = _goals[index];
                  final label = goal['label']!;
                  final isSelected = _selectedGoals.contains(label);
                  return GestureDetector(
                    onTap: () => _toggleGoal(label),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.10)
                            : colors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : colors.border,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(goal['emoji']!,
                              style: const TextStyle(fontSize: 24)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(label,
                                style: AppTextStyles.bodyLarge.copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                )),
                          ),
                          AnimatedScale(
                            scale: isSelected ? 1 : 0,
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutBack,
                            child: const Icon(Icons.check_circle,
                                color: AppColors.primary),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: (150 + index * 50).ms).slideX(
                        begin: 0.05, end: 0),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            AirbnbButton(
              label: _selectedGoals.isEmpty ? 'Select at least one' : 'Continue',
              onPressed: _selectedGoals.isNotEmpty ? _nextPage : null,
            ).animate().fadeIn(delay: 400.ms),
          ],
        ),
      ),
    );
  }

  // ── 2 · Goals response (image based on selection) ────────────────────────────
  Widget _buildGoalsResponseStep() {
    final colors = AppColors.of(context);
    final goal = _primaryGoal;
    return Column(
      children: [
        Expanded(
          flex: 5,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(goal['img']!),
                fit: BoxFit.cover,
              ),
            ),
          ).animate().fadeIn(duration: 800.ms),
        ),
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                Text(
                  'Plateful will help you ${goal['phrase']}.',
                  style: AppTextStyles.displayMedium
                      .copyWith(color: AppColors.primary),
                  textAlign: TextAlign.center,
                ).animate().fadeIn().slideY(begin: 0.1, end: 0),
                const SizedBox(height: 16),
                Text(
                  'We tailor everything around your goals so cooking feels easier from day one.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: colors.textSecondary, height: 1.5),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 200.ms),
                const Spacer(),
                AirbnbButton(label: 'Continue', onPressed: _nextPage)
                    .animate()
                    .fadeIn(delay: 400.ms),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── 5 · Diet preferences ─────────────────────────────────────────────────────
  static const List<Map<String, String>> _diets = [
    {'emoji': '🍽️', 'label': 'None'},
    {'emoji': '🌱', 'label': 'Vegan'},
    {'emoji': '🥦', 'label': 'Vegetarian'},
    {'emoji': '🥩', 'label': 'Keto'},
    {'emoji': '🦴', 'label': 'Paleo'},
    {'emoji': '🌾', 'label': 'Gluten-Free'},
  ];

  Widget _buildDietStep() {
    final colors = AppColors.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 96, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Any diet preferences?',
                    style: AppTextStyles.displayMedium)
                .animate()
                .fadeIn()
                .slideX(begin: 0.1, end: 0),
            const SizedBox(height: 10),
            Text('We use this to tailor recipes to you. You can change it later.',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: colors.textSecondary))
                .animate()
                .fadeIn(delay: 100.ms),
            const SizedBox(height: 28),
            Expanded(
              child: ListView.separated(
                itemCount: _diets.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final diet = _diets[index];
                  final label = diet['label']!;
                  final isSelected = _selectedDiet == label;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedDiet = label);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.10)
                            : colors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : colors.border,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(diet['emoji']!,
                              style: const TextStyle(fontSize: 24)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(label,
                                style: AppTextStyles.bodyLarge.copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                )),
                          ),
                          AnimatedScale(
                            scale: isSelected ? 1 : 0,
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutBack,
                            child: const Icon(Icons.check_circle,
                                color: AppColors.primary),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: (150 + index * 50).ms).slideX(
                        begin: 0.05, end: 0),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            AirbnbButton(label: 'Continue', onPressed: _nextPage)
                .animate()
                .fadeIn(delay: 400.ms),
          ],
        ),
      ),
    );
  }

  void _toggleGoal(String label) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedGoals.contains(label)) {
        _selectedGoals.remove(label);
      } else {
        if (_selectedGoals.length >= 2) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(
              content: Text('You can pick up to two goals.'),
              behavior: SnackBarBehavior.floating,
            ));
          return;
        }
        _selectedGoals.add(label);
      }
    });
  }

  // ── 2 · Import support ───────────────────────────────────────────────────────
  Widget _buildImportSupportStep() {
    final colors = AppColors.of(context);
    return Column(
      children: [
        Expanded(
          flex: 5,
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/import_from_anywhere.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, colors.bg],
                  stops: const [0.6, 1.0],
                ),
              ),
            ),
          ).animate().fadeIn(duration: 800.ms),
        ),
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                Text(
                  'Import from almost anywhere.',
                  style: AppTextStyles.displayMedium
                      .copyWith(color: AppColors.primary),
                  textAlign: TextAlign.center,
                ).animate().fadeIn().slideY(begin: 0.1, end: 0),
                const SizedBox(height: 14),
                Text(
                  'Share a link from TikTok, YouTube, or any blog and we turn it into a clean recipe.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: colors.textSecondary, height: 1.5),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.info_outline,
                          size: 16, color: AppColors.accent),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Instagram shared links support is coming soon',
                          style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 300.ms).scale(
                    begin: const Offset(0.95, 0.95), curve: Curves.easeOut),
                const Spacer(),
                AirbnbButton(label: 'See how it works', onPressed: _nextPage)
                    .animate()
                    .fadeIn(delay: 400.ms),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── 5 · Trial tease ──────────────────────────────────────────────────────────
  Widget _buildFreeTrialStep() {
    final colors = AppColors.of(context);
    final perks = <Map<String, String>>[
      {'emoji': '♾️', 'label': 'Unlimited intelligent recipe imports'},
      {'emoji': '🥑', 'label': 'Healthify and Tailor any recipe'},
      {'emoji': '🗓️', 'label': 'Intelligent weekly meal plans'},
      {'emoji': '🛒', 'label': 'Smart auto grocery lists'},
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
        child: Column(
          children: [
            const Spacer(),
            Container(
              width: 96,
              height: 96,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Image.asset('assets/images/play_store_512.png',
                  fit: BoxFit.cover),
            ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 24),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('7 DAYS FREE',
                  style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5)),
            ).animate().fadeIn(delay: 150.ms),
            const SizedBox(height: 16),
            Text(
              'Unlock Plateful Pro',
              style: AppTextStyles.displayLarge,
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),
            const SizedBox(height: 24),
            ...perks.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Text(e.value['emoji']!,
                          style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(e.value['label']!,
                            style: AppTextStyles.bodyLarge
                                .copyWith(fontWeight: FontWeight.w500)),
                      ),
                      const Icon(Icons.check_circle,
                          color: AppColors.primary, size: 20),
                    ],
                  ),
                ).animate().fadeIn(delay: (350 + e.key * 100).ms).slideX(
                    begin: 0.08, end: 0)),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_active_outlined,
                    size: 15, color: colors.textSecondary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'No surprises. We remind you 2 days before it ends.',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: colors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 750.ms),
            const SizedBox(height: 12),
            AirbnbButton(
              label: 'Start 7 day free trial',
              onPressed: _goToPaywallThenSignup,
            ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.3, end: 0),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _goToSignup,
              child: Text('Maybe later',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: colors.textSecondary)),
            ).animate().fadeIn(delay: 900.ms),
          ],
        ),
      ),
    );
  }
}

// ── 3 · Import tutorial (manual, press Next) ──────────────────────────────────
class _ImportTutorial extends StatefulWidget {
  final VoidCallback onComplete;
  const _ImportTutorial({required this.onComplete});

  @override
  State<_ImportTutorial> createState() => _ImportTutorialState();
}

class _ImportTutorialState extends State<_ImportTutorial> {
  final PageController _controller = PageController();
  int _step = 0;

  final List<Map<String, String>> _steps = const [
    {
      'title': 'Find a recipe',
      'desc': 'Browse your favourite social app or blog.',
      'img': 'assets/images/tutorial_Steps/1.png',
    },
    {
      'title': 'Share or copy the link',
      'desc': 'Send the link to Plateful or copy it.',
      'img': 'assets/images/tutorial_Steps/2.png',
    },
    {
      'title': 'Extract',
      'desc': 'Plateful turns it into a clean recipe card.',
      'img': 'assets/images/tutorial_Steps/3.png',
    },
  ];

  void _next() {
    if (_step < _steps.length - 1) {
      _controller.nextPage(
          duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    } else {
      widget.onComplete();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 56),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _step = i),
              itemCount: _steps.length,
              itemBuilder: (context, index) {
                final step = _steps[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.asset(step['img']!, fit: BoxFit.contain),
                        ).animate(key: ValueKey(index)).scale(
                            delay: 100.ms, curve: Curves.easeOutBack),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        '${index + 1}. ${step['title']}',
                        style: AppTextStyles.displayMedium
                            .copyWith(color: AppColors.primary),
                        textAlign: TextAlign.center,
                      ).animate(key: ValueKey('t$index')).fadeIn().slideY(),
                      const SizedBox(height: 12),
                      Text(
                        step['desc']!,
                        style: AppTextStyles.bodyLarge
                            .copyWith(color: colors.textSecondary),
                        textAlign: TextAlign.center,
                      ).animate(key: ValueKey('d$index')).fadeIn(delay: 150.ms),
                    ],
                  ),
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
                _steps.length,
                (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _step == index ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _step == index
                            ? AppColors.primary
                            : colors.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    )),
          ),
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: AirbnbButton(
              label: _step == _steps.length - 1 ? 'Try it now' : 'Next',
              onPressed: _next,
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── 7 · Setting up (animated logo + ticking checklist) ────────────────────────
class _SetupProgressStep extends StatefulWidget {
  final VoidCallback onComplete;
  final Set<String> goals;
  final String diet;
  const _SetupProgressStep({
    required this.onComplete,
    required this.goals,
    required this.diet,
  });

  @override
  State<_SetupProgressStep> createState() => _SetupProgressStepState();
}

class _SetupProgressStepState extends State<_SetupProgressStep> {
  late final List<String> _items;
  int _done = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final goalText = widget.goals.isEmpty
        ? 'your goals'
        : widget.goals.map((g) => g.toLowerCase()).join(' and ');
    _items = [
      'Building your recipe library',
      'Saving Korean BBQ Yum Yum Rice Bowls',
      widget.diet == 'None'
          ? 'Saving your taste preferences'
          : 'Applying your ${widget.diet} preferences',
      'Tuning Plateful to $goalText',
      'Preparing recipe import',
    ];
    _timer = Timer.periodic(const Duration(milliseconds: 750), (t) {
      if (_done < _items.length) {
        HapticFeedback.selectionClick();
        setState(() => _done++);
      } else {
        t.cancel();
        HapticFeedback.mediumImpact();
        Future.delayed(const Duration(milliseconds: 650), () {
          if (mounted) widget.onComplete();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final allDone = _done >= _items.length;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            // Logo with a pulsing brand ring
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary),
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.12),
                    ),
                  ),
                  Container(
                    width: 84,
                    height: 84,
                    clipBehavior: Clip.antiAlias,
                    decoration:
                        BoxDecoration(borderRadius: BorderRadius.circular(22)),
                    child: Image.asset('assets/images/play_store_512.png',
                        fit: BoxFit.cover),
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scale(
                        begin: const Offset(1, 1),
                        end: const Offset(1.06, 1.06),
                        duration: 900.ms,
                        curve: Curves.easeInOut,
                      ),
                ],
              ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
            ),
            const SizedBox(height: 32),
            Text(
              allDone ? 'Your kitchen is ready' : 'Setting everything up',
              style: AppTextStyles.displayMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            // Ticking checklist
            ..._items.asMap().entries.map((e) {
              final reached = e.key < _done;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: reached
                          ? const Icon(Icons.check_circle,
                                  color: AppColors.primary, size: 22)
                              .animate()
                              .scale(
                                  begin: const Offset(0.4, 0.4),
                                  duration: 280.ms,
                                  curve: Curves.easeOutBack)
                          : (e.key == _done
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                              AppColors.primary)),
                                )
                              : Icon(Icons.circle_outlined,
                                  size: 18, color: colors.border)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        e.value,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: reached
                              ? colors.textPrimary
                              : colors.textSecondary,
                          fontWeight:
                              reached ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
