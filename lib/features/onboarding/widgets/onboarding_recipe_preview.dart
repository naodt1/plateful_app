import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/airbnb_button.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../data/demo_recipe.dart';

/// Interactive onboarding demo of the pre-added recipe. Self-contained (no
/// Supabase / ProGate) so it runs before the user signs in. The user gets one
/// free Healthify and one free Tailor, each celebrated with a confetti burst;
/// after that the buttons show a Pro state.
class OnboardingRecipePreview extends StatefulWidget {
  final VoidCallback onContinue;

  /// The diet the user selected in the previous step (e.g. 'Vegan', 'None').
  /// Drives the Tailor demo so the swaps match what they chose.
  final String dietLabel;

  const OnboardingRecipePreview({
    super.key,
    required this.onContinue,
    this.dietLabel = 'None',
  });

  @override
  State<OnboardingRecipePreview> createState() =>
      _OnboardingRecipePreviewState();
}

class _OnboardingRecipePreviewState extends State<OnboardingRecipePreview> {
  late final ConfettiController _confetti;
  bool _healthifyUsed = false;
  bool _tailorUsed = false;

  @override
  void initState() {
    super.initState();
    _confetti =
        ConfettiController(duration: const Duration(milliseconds: 3500));
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  /// Satisfying reward buzz fired when a demo result lands with confetti.
  void _celebrate() {
    HapticFeedback.heavyImpact();
    _confetti.play();
  }

  void _savedToast(String message) {
    HapticFeedback.heavyImpact();
    _confetti.play();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary,
      ));
  }

  void _proHint(String feature) {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('$feature is a Pro feature. Start your free trial next.'),
        behavior: SnackBarBehavior.floating,
      ));
  }

  Future<void> _openHealthify() async {
    if (_healthifyUsed) {
      _proHint('Healthify');
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _healthifyUsed = true);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DemoResultSheet(
        title: 'Healthify Recipe',
        subtitle: 'AI powered suggestions',
        icon: Icons.eco,
        accent: AppColors.accent,
        builder: (_) => const _HealthifyDemoResult(result: kDemoHealthifyResult),
        onReady: _celebrate,
        saveLabel: 'Save healthier version',
        onSave: () => _savedToast('Healthier version saved to your recipe'),
      ),
    );
  }

  Future<void> _openTailor() async {
    if (_tailorUsed) {
      _proHint('Tailor');
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _tailorUsed = true);
    final diet = widget.dietLabel;
    final result = demoTailorResultFor(diet);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DemoResultSheet(
        title: 'Tailor Recipe',
        subtitle: diet == 'None'
            ? 'Personalised for you'
            : 'Tailored for your $diet diet',
        icon: Icons.tune,
        accent: AppColors.primary,
        builder: (_) => _TailorDemoResult(result: result),
        onReady: _celebrate,
        saveLabel: 'Save tailored recipe',
        onSave: () => _savedToast('Tailored recipe saved'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final recipe = kDemoRecipe;
    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero image
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(24)),
                      child: CachedNetworkImage(
                        imageUrl: recipe.imageUrl!,
                        height: 280,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const SkeletonLoader(
                            width: double.infinity, height: 280),
                        errorWidget: (_, __, ___) => Container(
                          height: 280,
                          color: colors.surface,
                          child: Icon(Icons.restaurant_menu,
                              size: 56, color: colors.border),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(recipe.title,
                                  style: AppTextStyles.displayMedium)
                              .animate()
                              .fadeIn()
                              .slideY(begin: 0.1, end: 0),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: recipe.tags
                                .map((t) => Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: colors.surface,
                                        borderRadius: BorderRadius.circular(20),
                                        border:
                                            Border.all(color: colors.border),
                                      ),
                                      child: Text(t,
                                          style: AppTextStyles.bodySmall
                                              .copyWith(
                                                  color: colors.textSecondary)),
                                    ))
                                .toList(),
                          ),
                          const SizedBox(height: 14),
                          Text(recipe.description,
                              style: AppTextStyles.bodyMedium.copyWith(
                                  color: colors.textSecondary, height: 1.5)),
                          const SizedBox(height: 20),
                          if (!(_tailorUsed && _healthifyUsed))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  const Icon(Icons.touch_app,
                                      size: 16, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Text('Try one free, tap below',
                                      style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          // Tailor + Healthify
                          Row(
                            children: [
                              Expanded(
                                child: _ActionButton(
                                  label: 'Tailor',
                                  icon: Icons.tune,
                                  background: AppColors.primary,
                                  locked: _tailorUsed,
                                  onTap: _openTailor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _ActionButton(
                                  label: 'Healthify',
                                  icon: Icons.eco,
                                  background: AppColors.accent,
                                  locked: _healthifyUsed,
                                  onTap: _openHealthify,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          Text('Ingredients',
                              style: AppTextStyles.headingMedium),
                          const SizedBox(height: 10),
                          ...recipe.ingredients.map((i) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 5),
                                child: Row(
                                  children: [
                                    const Icon(Icons.circle,
                                        size: 6, color: AppColors.primary),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _formatIngredient(i.amount, i.unit,
                                            i.name),
                                        style: AppTextStyles.bodyMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                          const SizedBox(height: 20),
                          Text('Steps', style: AppTextStyles.headingMedium),
                          const SizedBox(height: 10),
                          ...recipe.steps.asMap().entries.map((e) => Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 14),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 26,
                                      height: 26,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text('${e.key + 1}',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.primary)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(e.value,
                                          style: AppTextStyles.bodyMedium
                                              .copyWith(height: 1.45)),
                                    ),
                                  ],
                                ),
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 8, 20, MediaQuery.of(context).padding.bottom + 16),
              child: AirbnbButton(
                label: 'Continue',
                onPressed: widget.onContinue,
              ),
            ),
          ],
        ),
        // Confetti raining from the top across the whole width.
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            emissionFrequency: 0.08,
            numberOfParticles: 45,
            maxBlastForce: 32,
            minBlastForce: 14,
            gravity: 0.28,
            minimumSize: const Size(10, 10),
            maximumSize: const Size(22, 22),
            particleDrag: 0.04,
            shouldLoop: false,
            colors: const [
              AppColors.primary,
              AppColors.accent,
              Color(0xFF60A5FA),
              Color(0xFFF59E0B),
              Color(0xFFE5533D),
            ],
          ),
        ),
      ],
    );
  }

  String _formatIngredient(double amount, String unit, String name) {
    final amt = amount == amount.roundToDouble()
        ? amount.round().toString()
        : amount.toString();
    return [amt, unit, name].where((s) => s.trim().isNotEmpty).join(' ');
  }
}

// ── Action button (Tailor / Healthify) ────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color background;
  final bool locked;
  final VoidCallback onTap;
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final button = GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: locked ? background.withValues(alpha: 0.45) : background,
          borderRadius: BorderRadius.circular(14),
          boxShadow: locked
              ? null
              : [
                  BoxShadow(
                    color: background.withValues(alpha: 0.45),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(locked ? Icons.lock : icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );

    if (locked) return button;

    // Draw attention to the unused action: a gentle pulse plus a shimmer sweep.
    return button
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(
            begin: 1.0,
            end: 1.04,
            duration: 900.ms,
            curve: Curves.easeInOut)
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
            delay: 600.ms,
            duration: 1400.ms,
            color: Colors.white.withValues(alpha: 0.35));
  }
}

// ── Demo result sheet: skeleton then result, fires confetti when ready ────────
class _DemoResultSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final WidgetBuilder builder;
  final VoidCallback onReady;
  final String saveLabel;
  final VoidCallback onSave;
  const _DemoResultSheet({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.builder,
    required this.onReady,
    required this.saveLabel,
    required this.onSave,
  });

  @override
  State<_DemoResultSheet> createState() => _DemoResultSheetState();
}

class _DemoResultSheetState extends State<_DemoResultSheet> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() => _loading = false);
      widget.onReady();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                controller: controller,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: widget.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(widget.icon,
                              color: widget.accent, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.title,
                                style: AppTextStyles.headingMedium),
                            Text(widget.subtitle,
                                style: AppTextStyles.bodySmall),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (_loading)
                      const _ResultSkeleton()
                    else ...[
                      widget.builder(context),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            Navigator.of(context).pop();
                            widget.onSave();
                          },
                          icon: const Icon(Icons.check, size: 18),
                          label: Text(widget.saveLabel),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.accent,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 52),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultSkeleton extends StatelessWidget {
  const _ResultSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SkeletonText(width: 180, height: 16),
        const SizedBox(height: 16),
        ...List.generate(
          3,
          (_) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.of(context).surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonText(width: 150),
                SizedBox(height: 8),
                SkeletonText(width: double.infinity),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Healthify result body ─────────────────────────────────────────────────────
class _HealthifyDemoResult extends StatelessWidget {
  final Map<String, dynamic> result;
  const _HealthifyDemoResult({required this.result});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final caloriesSaved = result['caloriesSaved'] as num? ?? 0;
    final before = result['nutritionBefore'] as Map<String, dynamic>? ?? {};
    final after = result['nutritionAfter'] as Map<String, dynamic>? ?? {};
    final scoreBefore = result['healthScoreBefore'] as num? ?? 0;
    final scoreAfter = result['healthScoreAfter'] as num? ?? 0;
    final benefits = result['benefits'] as List? ?? [];
    final changes = result['changes'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Headline: calories saved + health score jump
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.trending_down, color: AppColors.accent, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Save ~$caloriesSaved calories',
                        style: const TextStyle(
                            color: AppColors.accent,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    Text('Per serving, without losing flavour',
                        style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              if (scoreAfter > 0)
                Column(
                  children: [
                    Text('$scoreBefore → $scoreAfter',
                        style: const TextStyle(
                            color: AppColors.accent,
                            fontSize: 15,
                            fontWeight: FontWeight.w800)),
                    Text('health score', style: AppTextStyles.caption),
                  ],
                ),
            ],
          ),
        ).animate().fadeIn().scale(duration: 300.ms),
        const SizedBox(height: 20),

        // Nutrition before → after
        Text('Nutrition per serving', style: AppTextStyles.headingMedium),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            children: [
              _NutriRow('Calories', before['calories'], after['calories'],
                  unit: '', goodWhenLower: true),
              _NutriRow('Protein', before['protein'], after['protein'],
                  unit: 'g', goodWhenLower: false),
              _NutriRow('Carbs', before['carbs'], after['carbs'],
                  unit: 'g', goodWhenLower: true),
              _NutriRow('Fat', before['fat'], after['fat'],
                  unit: 'g', goodWhenLower: true, last: true),
            ],
          ),
        ).animate().fadeIn(delay: 150.ms),
        const SizedBox(height: 20),

        // Benefit chips
        if (benefits.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: benefits
                .map((b) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle,
                              size: 14, color: AppColors.success),
                          const SizedBox(width: 6),
                          Text(b.toString(),
                              style: AppTextStyles.caption.copyWith(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ))
                .toList(),
          ).animate().fadeIn(delay: 250.ms),
          const SizedBox(height: 20),
        ],

        Text('Ingredient swaps', style: AppTextStyles.headingMedium),
        const SizedBox(height: 12),
        ...changes.asMap().entries.map((e) => _SwapCard(
              change: e.value as Map<String, dynamic>,
              index: e.key,
              pill: (e.value as Map<String, dynamic>)['benefit'] as String?,
              reason: (e.value as Map<String, dynamic>)['reason'] as String?,
            )),
      ],
    );
  }
}

// ── Tailor result body ────────────────────────────────────────────────────────
class _TailorDemoResult extends StatelessWidget {
  final Map<String, dynamic> result;
  const _TailorDemoResult({required this.result});

  @override
  Widget build(BuildContext context) {
    final assessment = result['overallAssessment'] as String? ?? '';
    final tip = result['chefTip'] as String? ?? '';
    final warnings = result['warnings'] as List? ?? [];
    final changes = result['changes'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (assessment.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.verified, color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(assessment,
                      style: AppTextStyles.bodyMedium.copyWith(height: 1.45)),
                ),
              ],
            ),
          ).animate().fadeIn().scale(duration: 300.ms),
          const SizedBox(height: 16),
        ],

        // Warnings
        ...warnings.map((w) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppColors.warning, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(w.toString(),
                          style: AppTextStyles.bodySmall
                              .copyWith(height: 1.4))),
                ],
              ),
            )),

        Text('Changes made', style: AppTextStyles.headingMedium),
        const SizedBox(height: 12),
        ...changes.asMap().entries.map((e) => _SwapCard(
              change: e.value as Map<String, dynamic>,
              index: e.key,
              reason: (e.value as Map<String, dynamic>)['reason'] as String?,
              confidence:
                  (e.value as Map<String, dynamic>)['confidence'] as String?,
              culinarySense: (e.value as Map<String, dynamic>)['culinarySense']
                  as String?,
              outcomeImpact: (e.value as Map<String, dynamic>)['outcomeImpact']
                  as String?,
            )),

        if (tip.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.local_fire_department,
                    color: AppColors.accent, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: AppTextStyles.bodySmall.copyWith(height: 1.45),
                      children: [
                        const TextSpan(
                            text: 'Chef tip  ',
                            style: TextStyle(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w700)),
                        TextSpan(text: tip),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 200.ms),
        ],
      ],
    );
  }
}

// ── Nutrition before → after row ──────────────────────────────────────────────
class _NutriRow extends StatelessWidget {
  final String label;
  final num? before;
  final num? after;
  final String unit;
  final bool goodWhenLower;
  final bool last;
  const _NutriRow(this.label, this.before, this.after,
      {required this.unit, required this.goodWhenLower, this.last = false});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final b = before ?? 0;
    final a = after ?? 0;
    final improved = goodWhenLower ? a < b : a > b;
    String fmt(num n) => n == n.roundToDouble()
        ? '${n.round()}$unit'
        : '${n.toStringAsFixed(1)}$unit';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: colors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
              flex: 3,
              child: Text(label, style: AppTextStyles.bodyMedium)),
          Expanded(
            flex: 2,
            child: Text(fmt(b),
                textAlign: TextAlign.right,
                style: AppTextStyles.bodySmall.copyWith(
                    color: colors.textSecondary,
                    decoration: TextDecoration.lineThrough)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(
                improved ? Icons.arrow_downward : Icons.arrow_forward,
                size: 13,
                color: improved ? AppColors.success : colors.textSecondary),
          ),
          Expanded(
            flex: 2,
            child: Text(fmt(a),
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color:
                        improved ? AppColors.success : colors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

// ── Shared swap card (Healthify + Tailor) ─────────────────────────────────────
class _SwapCard extends StatelessWidget {
  final Map<String, dynamic> change;
  final int index;
  final String? reason;
  final String? pill; // healthify benefit pill
  final String? confidence; // tailor
  final String? culinarySense; // tailor
  final String? outcomeImpact; // tailor
  const _SwapCard({
    required this.change,
    required this.index,
    this.reason,
    this.pill,
    this.confidence,
    this.culinarySense,
    this.outcomeImpact,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    change['original'] as String? ?? '',
                    style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                        decoration: TextDecoration.lineThrough,
                        fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward,
                    size: 14, color: colors.textSecondary),
              ),
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    change['replacement'] as String? ?? '',
                    style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (pill != null && pill!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(pill!,
                      style: const TextStyle(
                          color: AppColors.success,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
              ],
              if (confidence != null && confidence!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(confidence!,
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          ),
          if (reason != null && reason!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(reason!,
                style: AppTextStyles.bodySmall
                    .copyWith(fontWeight: FontWeight.w600)),
          ],
          if (culinarySense != null && culinarySense!.isNotEmpty)
            _InfoRow(
                icon: Icons.restaurant_outlined,
                text: culinarySense!,
                color: AppColors.success),
          if (outcomeImpact != null && outcomeImpact!.isNotEmpty)
            _InfoRow(
                icon: Icons.bubble_chart_outlined,
                text: outcomeImpact!,
                color: AppColors.warning),
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: 100 + index * 80));
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _InfoRow({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: AppTextStyles.caption
                    .copyWith(color: colors.textSecondary, height: 1.35)),
          ),
        ],
      ),
    );
  }
}
