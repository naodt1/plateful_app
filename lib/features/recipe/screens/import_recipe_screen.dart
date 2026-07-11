import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/providers/recipe_providers.dart';
import '../../../core/services/claude_service.dart';
import '../../subscription/pro_gate.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../models/recipe.dart';
import 'package:url_launcher/url_launcher.dart';

/// Screen shown when a link is shared into the app from another app
/// (Instagram, TikTok, YouTube, browser…). It extracts the recipe with AI,
/// saves it, and shows what was added.
class ImportRecipeScreen extends ConsumerStatefulWidget {
  final String sharedUrl;
  const ImportRecipeScreen({super.key, required this.sharedUrl});

  @override
  ConsumerState<ImportRecipeScreen> createState() => _ImportRecipeScreenState();
}

class _ImportRecipeScreenState extends ConsumerState<ImportRecipeScreen> {
  bool _loading = true;
  String? _error;
  String? _noRecipeReason; // set when extraction detects no recipe (e.g. login wall)
  Recipe? _saved;

  @override
  void initState() {
    super.initState();
    _import();
  }

  String _extractUrl(String raw) {
    // Shared text often contains caption + URL; pull the first http(s) link.
    final match = RegExp(r'https?://[^\s]+').firstMatch(raw);
    return match?.group(0) ?? raw.trim();
  }

  Future<void> _import() async {
    // Importing via share counts toward the free-import limit.
    if (!await ProGate.allowImport(context)) {
      if (mounted) {
        setState(() {
          _loading = false;
          _noRecipeReason =
              'You\'ve used all your free imports. Upgrade to Plateful Pro for unlimited recipe imports.';
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _noRecipeReason = null;
    });
    try {
      final url = _extractUrl(widget.sharedUrl);
      final data = await ClaudeService.extractRecipeFromUrl(url);
      await ProGate.recordImport();

      final userId = FirebaseService.currentUserId ?? '';
      final ingList = (data['ingredients'] as List? ?? []).map((e) {
        final m = e as Map<String, dynamic>;
        return Ingredient(
          name: m['name'] as String? ?? '',
          amount: (m['amount'] as num?)?.toDouble() ?? 1.0,
          unit: m['unit'] as String? ?? '',
        );
      }).toList();

      final nutritionRaw = data['nutrition'];
      final nutrition = nutritionRaw is Map<String, dynamic>
          ? Nutrition.fromJson(nutritionRaw)
          : null;

      final recipe = Recipe(
        id: const Uuid().v4(),
        userId: userId,
        title: data['title'] as String? ?? 'Imported Recipe',
        description: data['description'] as String? ?? '',
        imageUrl: data['image_url'] as String?,
        sourceUrl: url,
        sourceType: 'share',
        ingredients: ingList,
        steps: (data['steps'] as List? ?? []).map((e) => e.toString()).toList(),
        nutrition: nutrition,
        tags: (data['tags'] as List? ?? []).map((e) => e.toString()).toList(),
        createdAt: DateTime.now(),
        servings: (data['servings'] as num?)?.toInt() ?? 4,
      );

      final recipeId = await FirebaseService.saveRecipe(recipe);
      refreshRecipeData(ref); // refresh home screen
      if (mounted) {
        setState(() {
          _saved = recipe.copyWith(id: recipeId);
          _loading = false;
        });
      }
    } on NoRecipeFoundException catch (e) {
      // Platform blocks scraping (Instagram/TikTok login wall, etc.)
      if (mounted) {
        setState(() {
          _noRecipeReason = e.reason;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _close,
        ),
        title: Text('Importing Recipe', style: AppTextStyles.headingMedium),
      ),
      body: SafeArea(
        child: _loading
            ? _ImportingView(url: _extractUrl(widget.sharedUrl), colors: colors)
            : _noRecipeReason != null
                ? _NoRecipeView(
                    reason: _noRecipeReason!,
                    sharedUrl: _extractUrl(widget.sharedUrl),
                    onClose: _close,
                    colors: colors,
                  )
                : _error != null
                    ? _ErrorView(error: _error!, onRetry: _import, onClose: _close, colors: colors)
                    : _SuccessView(recipe: _saved!, onClose: _close, colors: colors),
      ),
    );
  }
}

// ── Importing (skeleton) ──────────────────────────────────────────────────────
class _ImportingView extends StatelessWidget {
  final String url;
  final AppColorScheme colors;
  const _ImportingView({required this.url, required this.colors});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: AppColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Reading the link with AI…',
                          style: AppTextStyles.labelLarge),
                      const SizedBox(height: 2),
                      Text(url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: colors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ).animate(onPlay: (c) => c.repeat()).shimmer(
              duration: 1400.ms, color: AppColors.primary.withValues(alpha: 0.15)),
          const SizedBox(height: 24),
          const SkeletonLoader(width: double.infinity, height: 180, borderRadius: 16),
          const SizedBox(height: 16),
          const SkeletonText(width: 220, height: 24),
          const SizedBox(height: 10),
          const SkeletonText(width: double.infinity),
          const SizedBox(height: 6),
          const SkeletonText(width: 260),
          const SizedBox(height: 24),
          const SkeletonText(width: 140, height: 18),
          const SizedBox(height: 12),
          ...List.generate(
              4,
              (_) => const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: SkeletonText(width: double.infinity),
                  )),
        ],
      ),
    );
  }
}

// ── Error ─────────────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  final VoidCallback onClose;
  final AppColorScheme colors;
  const _ErrorView(
      {required this.error,
      required this.onRetry,
      required this.onClose,
      required this.colors});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: colors.textSecondary),
            const SizedBox(height: 16),
            Text("Couldn't import recipe",
                style: AppTextStyles.headingMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(error,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary, fontSize: 13)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text('Try again'),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: onClose, child: const Text('Cancel')),
          ],
        ),
      ),
    );
  }
}

// ── No Recipe Found ───────────────────────────────────────────────────────────
class _NoRecipeView extends StatelessWidget {
  final String reason;
  final String sharedUrl;
  final VoidCallback onClose;
  final AppColorScheme colors;
  const _NoRecipeView({
    required this.reason,
    required this.sharedUrl,
    required this.onClose,
    required this.colors,
  });

  bool get _isInstagram => sharedUrl.contains('instagram.com');
  bool get _isTikTok => sharedUrl.contains('tiktok.com');

  String get _platformName {
    if (_isInstagram) return 'Instagram';
    if (_isTikTok) return 'TikTok';
    return 'this platform';
  }

  IconData get _platformIcon {
    if (_isInstagram) return Icons.camera_alt_outlined;
    if (_isTikTok) return Icons.music_video_outlined;
    return Icons.link_off;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          24, 32, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon badge
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: colors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: colors.border, width: 1.5),
            ),
            child: Icon(_platformIcon, size: 36, color: colors.textSecondary),
          ).animate().scale(begin: const Offset(0.7, 0.7), duration: 350.ms, curve: Curves.easeOut),
          const SizedBox(height: 20),

          Text(
            'No recipe found',
            style: AppTextStyles.headingMedium,
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 100.ms),
          const SizedBox(height: 10),

          Text(
            '$_platformName requires a login to view this content, so Plateful couldn\'t read the recipe from the link.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textSecondary, height: 1.55, fontSize: 14),
          ).animate().fadeIn(delay: 150.ms),
          const SizedBox(height: 32),

          // Tips card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('How to import recipes from $_platformName',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: colors.textPrimary)),
                const SizedBox(height: 14),
                _Tip(
                  number: '1',
                  text: 'Open the post in the $_platformName app.',
                  colors: colors,
                ),
                _Tip(
                  number: '2',
                  text: 'Copy the recipe text from the caption or comments.',
                  colors: colors,
                ),
                _Tip(
                  number: '3',
                  text: 'In Plateful, tap "Add Recipe" and paste the text there.',
                  colors: colors,
                ),
              ],
            ),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 24),

          // Open in browser button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final uri = Uri.tryParse(sharedUrl);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
                }
              },
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text('Open in $_platformName'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 52),
                side: BorderSide(color: colors.border),
                foregroundColor: colors.textPrimary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Add manually button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.go('/recipe/add'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text('Add Recipe Manually',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(onPressed: onClose, child: const Text('Cancel')),
        ],
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  final String number;
  final String text;
  final AppColorScheme colors;
  const _Tip({required this.number, required this.text, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(number,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 13, color: colors.textSecondary, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

// ── Success ───────────────────────────────────────────────────────────────────
class _SuccessView extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onClose;
  final AppColorScheme colors;
  const _SuccessView(
      {required this.recipe, required this.onClose, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Success banner
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                          color: AppColors.primary, shape: BoxShape.circle),
                      child: const Icon(Icons.check, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Added to Plateful',
                          style: AppTextStyles.headingMedium),
                    ),
                  ],
                ).animate().fadeIn().slideX(begin: -0.1, end: 0),
                const SizedBox(height: 20),

                // Image
                if (recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: recipe.imageUrl!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const SkeletonLoader(
                          width: double.infinity, height: 200, borderRadius: 16),
                      errorWidget: (_, __, ___) => Container(
                        height: 200,
                        color: colors.surface,
                        child: Icon(Icons.restaurant_menu,
                            size: 48, color: colors.border),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

                Text(recipe.title,
                    style: AppTextStyles.displayMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                if (recipe.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(recipe.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.textSecondary, height: 1.5)),
                ],
                const SizedBox(height: 16),

                // Quick stats
                Row(
                  children: [
                    _Stat(
                        icon: Icons.format_list_bulleted,
                        label: '${recipe.ingredients.length} ingredients',
                        colors: colors),
                    const SizedBox(width: 20),
                    _Stat(
                        icon: Icons.list_alt,
                        label: '${recipe.steps.length} steps',
                        colors: colors),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Bottom actions
        Padding(
          padding: EdgeInsets.fromLTRB(
              20, 8, 20, MediaQuery.of(context).padding.bottom + 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onClose,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    side: BorderSide(color: colors.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Done', style: TextStyle(color: colors.textPrimary)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => context.go('/recipe/${recipe.id}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text('View Recipe',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final AppColorScheme colors;
  const _Stat({required this.icon, required this.label, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                color: colors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}
