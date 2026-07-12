import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/services/claude_service.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../core/utils/error_messages.dart';

class PantrySuggestionsSheet extends StatefulWidget {
  final List<String> pantryItems;

  const PantrySuggestionsSheet({super.key, required this.pantryItems});

  @override
  State<PantrySuggestionsSheet> createState() => _PantrySuggestionsSheetState();
}

class _PantrySuggestionsSheetState extends State<PantrySuggestionsSheet> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _suggestions = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    try {
      final suggestions =
          await ClaudeService.suggestFromPantry(widget.pantryItems);
      setState(() {
        _suggestions = suggestions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = friendlyError(e);
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
                          color: AppColors.of(context).surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.auto_awesome,
                            color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Recipe Ideas', style: AppTextStyles.headingMedium),
                          Text('Based on your pantry',
                              style: AppTextStyles.bodySmall),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (_isLoading)
                    Column(
                      children: List.generate(
                        3,
                        (_) => Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.of(context).surface,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SkeletonText(width: 180, height: 16),
                              SizedBox(height: 8),
                              SkeletonText(width: double.infinity),
                              SizedBox(height: 4),
                              SkeletonText(width: 240),
                            ],
                          ),
                        ),
                      ),
                    )
                  else if (_error != null)
                    Text(_error ?? 'Something went wrong. Please try again.',
                        style: const TextStyle(color: AppColors.error))
                  else if (_suggestions.isEmpty)
                    Text(
                        'No suggestions found. Try adding more ingredients to your pantry.',
                        style: TextStyle(color: AppColors.of(context).textSecondary))
                  else
                    ..._suggestions.asMap().entries.map(
                          (e) => _SuggestionCard(
                            suggestion: e.value,
                            index: e.key,
                          ),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final Map<String, dynamic> suggestion;
  final int index;

  const _SuggestionCard({required this.suggestion, required this.index});

  @override
  Widget build(BuildContext context) {
    final missing = suggestion['missingIngredients'] as List? ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.of(context).border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            suggestion['title'] as String? ?? '',
            style: AppTextStyles.labelLarge,
          ),
          const SizedBox(height: 4),
          Text(
            suggestion['description'] as String? ?? '',
            style: AppTextStyles.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shopping_cart_outlined,
                    size: 14, color: AppColors.warning),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Need: ${missing.join(', ')}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: 100 + index * 80));
  }
}
