import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Shown while a freshly imported recipe is being rewritten for the user's
/// diet.
///
/// Deliberately different from the general importing animation: this stage is
/// not "reading", it is "swapping". So the animation shows ingredients being
/// replaced one at a time, the same from and to language the recipe itself
/// uses afterwards, which makes the wait explain the feature instead of just
/// filling it.
class AdaptingLoader extends StatefulWidget {
  /// The diet or allergy label being adapted for, used to pick plausible swaps.
  final String dietLabel;
  final double width;

  const AdaptingLoader({
    super.key,
    required this.dietLabel,
    this.width = 320,
  });

  @override
  State<AdaptingLoader> createState() => _AdaptingLoaderState();
}

class _AdaptingLoaderState extends State<AdaptingLoader>
    with TickerProviderStateMixin {
  late final AnimationController _cycle; // advances one swap at a time
  late final AnimationController _glow;  // slow ambient breathing

  int _index = 0;

  /// Illustrative swaps per diet. These are only ever shown during the wait;
  /// the real swaps come back from the model and replace them.
  static const _byDiet = <String, List<List<String>>>{
    'Vegan': [
      ['🥛 milk', '🥥 coconut milk'],
      ['🧈 butter', '🫒 olive oil'],
      ['🍯 honey', '🍁 maple syrup'],
      ['🧀 parmesan', '🌰 nutritional yeast'],
    ],
    'Vegetarian': [
      ['🥓 pancetta', '🍄 mushrooms'],
      ['🍗 chicken stock', '🥕 vegetable stock'],
      ['🐟 fish sauce', '🧂 soy sauce'],
    ],
    'Keto': [
      ['🍚 white rice', '🥦 cauliflower rice'],
      ['🍝 pasta', '🥒 courgette ribbons'],
      ['🍞 breadcrumbs', '🌰 almond flour'],
    ],
    'Paleo': [
      ['🌾 flour', '🥥 coconut flour'],
      ['🥛 cream', '🥥 coconut cream'],
      ['🍚 rice', '🥦 cauliflower rice'],
    ],
    'Gluten-Free': [
      ['🍝 pasta', '🌽 corn pasta'],
      ['🌾 flour', '🌰 almond flour'],
      ['🧂 soy sauce', '🥢 tamari'],
    ],
    'Halal': [
      ['🥓 bacon', '🥩 beef strips'],
      ['🍷 white wine', '🍋 lemon and stock'],
    ],
  };

  static const _fallback = <List<String>>[
    ['🥛 dairy', '🌱 plant based'],
    ['🧈 butter', '🫒 olive oil'],
    ['🍚 white rice', '🥦 cauliflower rice'],
  ];

  List<List<String>> get _swaps =>
      _byDiet[widget.dietLabel] ?? _fallback;

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _cycle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..addStatusListener((s) {
        if (s != AnimationStatus.completed) return;
        if (!mounted) return;
        setState(() => _index = (_index + 1) % _swaps.length);
        _cycle.forward(from: 0);
      });
    _cycle.forward();
  }

  @override
  void dispose() {
    _cycle.dispose();
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final swap = _swaps[_index];
    return SizedBox(
      width: widget.width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _glow,
            builder: (context, child) {
              final t = _glow.value;
              return Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    AppColors.primary.withValues(alpha: 0.10 + t * 0.10),
                    AppColors.primary.withValues(alpha: 0.0),
                  ]),
                ),
                child: child,
              );
            },
            child: _SwapDial(controller: _cycle),
          ),
          const SizedBox(height: 26),
          // The swap itself, crossfading as each one completes.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 420),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.14),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                    parent: anim, curve: Curves.easeOutCubic)),
                child: child,
              ),
            ),
            child: _SwapRow(
              key: ValueKey(_index),
              from: swap[0],
              to: swap[1],
              progress: _cycle,
            ),
          ),
        ],
      ),
    );
  }
}

/// A ring that fills once per swap, so the wait reads as progress rather than
/// an indefinite spinner.
class _SwapDial extends StatelessWidget {
  final Animation<double> controller;
  const _SwapDial({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => CustomPaint(
        size: const Size(74, 74),
        painter: _DialPainter(controller.value),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  final double t;
  _DialPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 4;

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppColors.primary.withValues(alpha: 0.16),
    );

    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi * Curves.easeInOut.transform(t),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..shader = const LinearGradient(
          colors: [AppColors.primary, AppColors.accent],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    // Two arrows chasing each other, the swap made literal.
    final tp = TextPainter(
      text: const TextSpan(
        text: '⇄',
        style: TextStyle(fontSize: 26, color: AppColors.primary),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(math.sin(t * math.pi) * 0.18);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DialPainter old) => old.t != t;
}

/// One "from becomes to" line, matching how swaps are shown on the recipe.
class _SwapRow extends StatelessWidget {
  final String from;
  final String to;
  final Animation<double> progress;

  const _SwapRow({
    super.key,
    required this.from,
    required this.to,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) {
        // The replacement settles in over the first half of the cycle.
        final arrive =
            Curves.easeOutCubic.transform((progress.value * 2).clamp(0.0, 1.0));
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: _Chip(
                    label: from,
                    background: AppColors.error.withValues(alpha: 0.10),
                    foreground: AppColors.error,
                    strikethrough: true,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(Icons.arrow_forward_rounded,
                      size: 16, color: colors.textSecondary),
                ),
                Flexible(
                  child: Opacity(
                    opacity: arrive,
                    child: Transform.translate(
                      offset: Offset(10 * (1 - arrive), 0),
                      child: _Chip(
                        label: to,
                        background: AppColors.primary.withValues(alpha: 0.12),
                        foreground: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final bool strikethrough;

  const _Chip({
    required this.label,
    required this.background,
    required this.foreground,
    this.strikethrough = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.bodySmall.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
          decoration: strikethrough ? TextDecoration.lineThrough : null,
          decorationColor: foreground,
        ),
      ),
    );
  }
}
