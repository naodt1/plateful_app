import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// "Continue with Google" button using the official multi-colour Google "G"
/// (drawn with a CustomPainter, so no image asset is required).
class GoogleButton extends StatelessWidget {
  final VoidCallback onPressed;
  const GoogleButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: colors.border, width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          foregroundColor: colors.textPrimary,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CustomPaint(painter: _GoogleLogoPainter()),
            ),
            const SizedBox(width: 12),
            Text('Continue with Google',
                style: AppTextStyles.labelLarge
                    .copyWith(color: colors.textPrimary)),
          ],
        ),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  static const _blue = Color(0xFF4285F4);
  static const _red = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final stroke = size.width * 0.22;
    final radius = r - stroke / 2;
    final rect = Rect.fromCircle(center: c, radius: radius);

    Paint p(Color col) => Paint()
      ..color = col
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    double deg(double d) => d * math.pi / 180;

    // Four arcs approximating the Google "G" ring.
    canvas.drawArc(rect, deg(-20), deg(80), false, p(_blue));   // right (blue)
    canvas.drawArc(rect, deg(60), deg(70), false, p(_green));   // bottom (green)
    canvas.drawArc(rect, deg(130), deg(90), false, p(_yellow)); // left (yellow)
    canvas.drawArc(rect, deg(220), deg(95), false, p(_red));    // top (red)

    // The horizontal bar of the G.
    final barPaint = Paint()
      ..color = _blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    canvas.drawLine(
      Offset(c.dx, c.dy),
      Offset(c.dx + radius + stroke / 2, c.dy),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
