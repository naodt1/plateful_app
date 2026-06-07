import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/services/claude_service.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../models/recipe.dart';

class HealthifySheet extends StatefulWidget {
  final Recipe recipe;

  const HealthifySheet({super.key, required this.recipe});

  @override
  State<HealthifySheet> createState() => _HealthifySheetState();
}

class _HealthifySheetState extends State<HealthifySheet> {
  bool _isLoading = true;
  Map<String, dynamic>? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _healthify();
  }

  Future<void> _healthify() async {
    try {
      final result = await ClaudeService.healthifyRecipe(widget.recipe.toJson());
      setState(() {
        _result = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.of(context).bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.of(context).border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
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
                          color: AppColors.accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.eco,
                            color: AppColors.accent, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Healthify Recipe',
                              style: AppTextStyles.headingMedium),
                          Text('AI-powered suggestions',
                              style: AppTextStyles.bodySmall),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (_isLoading) ...[
                    _HealthifySkeleton(),
                  ] else if (_error != null) ...[
                    Text('Error: $_error',
                        style: const TextStyle(color: AppColors.error)),
                  ] else if (_result != null) ...[
                    _HealthifyResults(result: _result!),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthifySkeleton extends StatelessWidget {
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
                SizedBox(height: 4),
                SkeletonText(width: 200),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HealthifyResults extends StatelessWidget {
  final Map<String, dynamic> result;

  const _HealthifyResults({required this.result});

  @override
  Widget build(BuildContext context) {
    final caloriesSaved = result['caloriesSaved'] as num? ?? 0;
    final changes = result['changes'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (caloriesSaved > 0) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.accent.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.trending_down,
                    color: AppColors.accent, size: 28),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Save ~$caloriesSaved calories',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Per serving with these swaps',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn().scale(duration: 300.ms),
          const SizedBox(height: 20),
        ],
        Text('Ingredient Swaps', style: AppTextStyles.headingMedium),
        const SizedBox(height: 12),
        if (changes.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.of(context).surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'This recipe is already quite healthy! No major swaps needed.',
              style: TextStyle(color: AppColors.of(context).textSecondary),
            ),
          )
        else
          ...changes.asMap().entries.map((entry) {
            final change = entry.value as Map<String, dynamic>;
            return _ChangeCard(change: change, index: entry.key);
          }),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: const Text('Continue with this recipe',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _ChangeCard extends StatelessWidget {
  final Map<String, dynamic> change;
  final int index;

  const _ChangeCard({required this.change, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.of(context).border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward, size: 14, color: AppColors.of(context).textSecondary),
              ),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    change['replacement'] as String? ?? '',
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            change['reason'] as String? ?? '',
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: 100 + index * 80));
  }
}
