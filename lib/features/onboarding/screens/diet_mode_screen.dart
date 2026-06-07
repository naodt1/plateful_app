import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/airbnb_button.dart';

class DietModeScreen extends StatefulWidget {
  const DietModeScreen({super.key});

  @override
  State<DietModeScreen> createState() => _DietModeScreenState();
}

class _DietModeScreenState extends State<DietModeScreen> {
  String _selected = 'None';

  static const _diets = [
    ('None', '🍽️'),
    ('Vegan', '🌱'),
    ('Vegetarian', '🥦'),
    ('Keto', '🥩'),
    ('Paleo', '🦴'),
    ('Gluten-Free', '🌾'),
    ('Halal', '☪️'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(context).bg,
      appBar: AppBar(
        backgroundColor: AppColors.of(context).bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your diet\npreferences', style: AppTextStyles.displayLarge)
                  .animate()
                  .fadeIn()
                  .slideX(begin: -0.1, end: 0),
              const SizedBox(height: 8),
              Text(
                "We'll personalize your experience based on your diet.",
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.of(context).textSecondary),
              ).animate().fadeIn(delay: 100.ms),
              const SizedBox(height: 36),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _diets.asMap().entries.map((entry) {
                  final i = entry.key;
                  final (name, emoji) = entry.value;
                  final isSelected = _selected == name;
                  return GestureDetector(
                    onTap: () => setState(() => _selected = name),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.of(context).surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.of(context).border,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(emoji,
                              style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.of(context).textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: Duration(milliseconds: 100 + i * 50));
                }).toList(),
              ),
              const Spacer(),
              AirbnbButton(
                label: 'Continue',
                onPressed: () => context.push('/signup',
                    extra: {'diet_mode': _selected}),
              ).animate().fadeIn(delay: 400.ms),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
