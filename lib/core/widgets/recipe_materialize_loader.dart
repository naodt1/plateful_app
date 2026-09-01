import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A distinctive "AI adapting the recipe" animation.
///
/// A central glowing plate pulses while ingredient emojis orbit and are pulled
/// into it; a sweeping scan line passes over structured "recipe lines" that
/// assemble beneath, as if the messy link is being transformed into a clean,
/// organised recipe card. Purpose-built for Plateful — nothing generic here.
class RecipeMaterializeLoader extends StatefulWidget {
  final double size;
  const RecipeMaterializeLoader({super.key, this.size = 200});

  @override
  State<RecipeMaterializeLoader> createState() =>
      _RecipeMaterializeLoaderState();
}

class _RecipeMaterializeLoaderState extends State<RecipeMaterializeLoader>
    with TickerProviderStateMixin {
  late final AnimationController _orbit; // continuous rotation
  late final AnimationController _pulse; // plate breathing + glow
  late final AnimationController _scan; // sweeping scan line + line assembly

  static const _foods = [
    '🍅', '🥑', '🧄', '🥕', '🌿', '🧅', '🍋', '🫑', '🧀', '🥚',
  ];

  @override
  void initState() {
    super.initState();
    _orbit = AnimationController(
        vsync: this, duration: const Duration(seconds: 6))
      ..repeat();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _scan = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat();
  }

  @override
  void dispose() {
    _orbit.dispose();
    _pulse.dispose();
    _scan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s,
      height: s,
      child: AnimatedBuilder(
        animation: Listenable.merge([_orbit, _pulse, _scan]),
        builder: (context, _) {
          final orbit = _orbit.value * 2 * math.pi;
          final pulse = _pulse.value; // 0..1
          final scan = _scan.value; // 0..1
          final glow = 0.35 + pulse * 0.4;

          return Stack(
            alignment: Alignment.center,
            children: [
              // Soft radial glow behind the plate.
              Container(
                width: s * 0.7,
                height: s * 0.7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: glow * 0.5),
                      AppColors.accent.withValues(alpha: glow * 0.15),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),

              // Dashed orbit ring.
              CustomPaint(
                size: Size(s * 0.86, s * 0.86),
                painter: _OrbitRingPainter(
                  rotation: orbit * 0.5,
                  color: AppColors.primary.withValues(alpha: 0.25),
                ),
              ),

              // Orbiting ingredients being pulled inward.
              for (var i = 0; i < 6; i++)
                _orbitingFood(s, orbit, i),

              // Central plate + fork/knife glyph, breathing.
              Transform.scale(
                scale: 0.94 + pulse * 0.08,
                child: Container(
                  width: s * 0.34,
                  height: s * 0.34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary,
                        Color(0xFF255F46),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: glow),
                        blurRadius: s * 0.18,
                        offset: Offset(0, s * 0.03),
                      ),
                    ],
                  ),
                  child: Icon(Icons.restaurant_rounded,
                      color: Colors.white, size: s * 0.16),
                ),
              ),

              // Sweeping scan line across the plate — the "reading" cue.
              Positioned.fill(
                child: ClipOval(
                  child: Align(
                    alignment: Alignment(0, -1 + scan * 2),
                    child: Container(
                      height: s * 0.02,
                      width: s * 0.5,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            AppColors.accent.withValues(alpha: 0.9),
                            Colors.transparent,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.6),
                            blurRadius: s * 0.04,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Recipe lines assembling at the bottom (the "clean output").
              Positioned(
                bottom: s * 0.02,
                child: _AssemblingLines(progress: scan, width: s * 0.6),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _orbitingFood(double s, double orbit, int i) {
    // Each item at a fixed angle offset, radius pulses in slightly (pulled in).
    final angle = orbit + (i / 6) * 2 * math.pi;
    // A per-item phase so they "breathe" toward the plate at different times.
    final pull = 0.5 + 0.5 * math.sin(orbit * 1.5 + i);
    final radius = s * (0.30 + 0.10 * pull);
    final dx = math.cos(angle) * radius;
    final dy = math.sin(angle) * radius;
    final scale = 0.7 + (1 - pull) * 0.5; // smaller as it nears the plate
    final opacity = (0.35 + pull * 0.6).clamp(0.0, 1.0);

    return Transform.translate(
      offset: Offset(dx, dy),
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          child: Text(_foods[i % _foods.length],
              style: TextStyle(fontSize: s * 0.11)),
        ),
      ),
    );
  }
}

class _OrbitRingPainter extends CustomPainter {
  final double rotation;
  final Color color;
  _OrbitRingPainter({required this.rotation, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..color = color;

    const dashes = 40;
    const sweep = 2 * math.pi / dashes;
    for (var i = 0; i < dashes; i++) {
      final start = rotation + i * sweep;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep * 0.45,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitRingPainter old) =>
      old.rotation != rotation || old.color != color;
}

/// Three short "recipe lines" that fill from left to right in sequence,
/// suggesting a clean structured recipe being written out.
class _AssemblingLines extends StatelessWidget {
  final double progress; // 0..1 loop
  final double width;
  const _AssemblingLines({required this.progress, required this.width});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(3, (i) {
        // Stagger each line's fill across the loop.
        final phase = (progress * 3 - i).clamp(0.0, 1.0);
        final w = width * (0.55 + 0.45 * (i.isEven ? 1 : 0.7));
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.5),
          child: Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Stack(
                children: [
                  Container(
                    width: w,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Container(
                    width: w * phase,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }),
    );
  }
}
