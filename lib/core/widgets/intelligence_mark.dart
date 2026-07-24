import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Plateful's own mark for intelligent features — a warm gradient badge instead
/// of the generic sparkle every other app uses.
class IntelligenceMark extends StatelessWidget {
  final double size;
  final IconData icon;

  const IntelligenceMark({
    super.key,
    this.size = 36,
    this.icon = Icons.soup_kitchen_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, Color(0xFF7C6CE4), AppColors.accent],
        ),
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: size * 0.35,
            offset: Offset(0, size * 0.1),
          ),
        ],
      ),
      child: Icon(icon, size: size * 0.56, color: Colors.white),
    );
  }
}

/// Same gradient as [IntelligenceMark] but as a bare glyph, for use inline in
/// rows where a filled badge would be too heavy.
class IntelligenceGlyph extends StatelessWidget {
  final double size;
  final IconData icon;

  const IntelligenceGlyph({
    super.key,
    this.size = 18,
    this.icon = Icons.soup_kitchen_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.primary, Color(0xFF7C6CE4), AppColors.accent],
      ).createShader(rect),
      child: Icon(icon, size: size, color: Colors.white),
    );
  }
}

/// A cooking scene shown while a recipe is being read and prepared: a pan that
/// rocks over rising steam while ingredients drop in one after another.
class CookingLoader extends StatefulWidget {
  final double size;
  const CookingLoader({super.key, this.size = 150});

  @override
  State<CookingLoader> createState() => _CookingLoaderState();
}

class _CookingLoaderState extends State<CookingLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  Timer? _timer;
  int _index = 0;

  static const _foods = ['🥑', '🍅', '🧄', '🥕', '🌿', '🧅', '🍋', '🫑'];

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _timer = Timer.periodic(const Duration(milliseconds: 1100), (_) {
      if (mounted) setState(() => _index = (_index + 1) % _foods.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s,
      height: s,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value; // 0..1
          // Gentle rocking of the pan.
          final wobble = math.sin(t * 2 * math.pi) * 0.05;
          return Stack(
            alignment: Alignment.center,
            children: [
              // Steam wisps
              for (var i = 0; i < 3; i++)
                _Steam(
                  progress: (t + i / 3) % 1.0,
                  dx: (i - 1) * s * 0.16,
                  size: s,
                ),

              // The ingredient dropping in
              Positioned(
                top: s * 0.10,
                child: _DroppingFood(
                  key: ValueKey(_index),
                  emoji: _foods[_index],
                  size: s * 0.20,
                  travel: s * 0.26,
                ),
              ),

              // Pan
              Align(
                alignment: Alignment.bottomCenter,
                child: Transform.rotate(
                  angle: wobble,
                  child: Container(
                    width: s * 0.74,
                    height: s * 0.42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primary, Color(0xFF255F46)],
                      ),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(s * 0.06),
                        bottom: Radius.circular(s * 0.30),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.30),
                          blurRadius: s * 0.14,
                          offset: Offset(0, s * 0.05),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Steam extends StatelessWidget {
  final double progress; // 0..1
  final double dx;
  final double size;

  const _Steam({required this.progress, required this.dx, required this.size});

  @override
  Widget build(BuildContext context) {
    final rise = size * 0.30 * progress;
    final opacity = (1.0 - progress).clamp(0.0, 1.0) * 0.5;
    return Positioned(
      bottom: size * 0.44 + rise,
      left: size / 2 + dx - size * 0.03,
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: size * 0.06,
          height: size * 0.13,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(size),
          ),
        ),
      ),
    );
  }
}

/// One ingredient falling toward the pan, fading out as it lands.
class _DroppingFood extends StatefulWidget {
  final String emoji;
  final double size;
  final double travel;

  const _DroppingFood({
    super.key,
    required this.emoji,
    required this.size,
    required this.travel,
  });

  @override
  State<_DroppingFood> createState() => _DroppingFoodState();
}

class _DroppingFoodState extends State<_DroppingFood>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeInCubic.transform(_c.value);
        return Transform.translate(
          offset: Offset(0, widget.travel * t),
          child: Opacity(
            opacity: (1.0 - math.pow(t, 3).toDouble()).clamp(0.0, 1.0),
            child: Transform.rotate(
              angle: t * 0.8,
              child: Text(widget.emoji,
                  style: TextStyle(fontSize: widget.size)),
            ),
          ),
        );
      },
    );
  }
}
