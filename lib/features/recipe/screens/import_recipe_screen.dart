import 'dart:async';
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
import '../../subscription/paywall.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/meta_ads_service.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/recipe_adapter.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../core/widgets/intelligence_mark.dart';
import '../../../core/widgets/adapting_loader.dart';
import '../../../models/recipe.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/utils/error_messages.dart';
import '../widgets/collection_picker_sheet.dart';

/// Screen shown when a link is shared into the app from another app
/// (Instagram, TikTok, YouTube, browser…). It extracts the recipe,
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
  bool _outOfImports = false; // free allowance spent and the user declined Pro
  String? _adaptingFor; // diet label while the recipe is being rewritten
  Recipe? _saved;
  String _status = _stages.first;
  Timer? _stageTimer;
  int _stage = 0;

  /// Rotating messages so a 20-second extraction doesn't feel stalled.
  static const _stages = [
    'Reading the recipe…',
    'Pulling out the ingredients…',
    'Writing up the steps…',
    'Working out the macros…',
  ];

  @override
  void initState() {
    super.initState();
    _startStageMessages();
    _import();
  }

  void _startStageMessages() {
    _stageTimer?.cancel();
    _stageTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _stage >= _stages.length - 1) return;
      setState(() => _status = _stages[++_stage]);
    });
  }

  @override
  void dispose() {
    _stageTimer?.cancel();
    super.dispose();
  }

  /// Buckets the link so analytics can show which platforms fail most.
  String _sourceOf(String url) {
    final u = url.toLowerCase();
    if (u.contains('tiktok.com')) return 'tiktok';
    if (u.contains('instagram.com')) return 'instagram';
    if (u.contains('youtube.com') || u.contains('youtu.be')) return 'youtube';
    return 'website';
  }

  String _extractUrl(String raw) {
    // Shared text often contains caption + URL; pull the first http(s) link.
    final match = RegExp(r'https?://[^\s]+').firstMatch(raw);
    return match?.group(0) ?? raw.trim();
  }

  Future<void> _import() async {
    // Importing via share counts toward the free-import limit. allowImport
    // explains the limit and only opens the paywall if the user asks for it.
    if (!await ProGate.allowImport(context)) {
      if (mounted) {
        setState(() {
          _loading = false;
          _outOfImports = true;
        });
        Analytics.paywallDismissed('import_limit');
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _noRecipeReason = null;
      _outOfImports = false;
    });
    final url = _extractUrl(widget.sharedUrl);
    final source = _sourceOf(url);
    final startedAt = DateTime.now();
    Analytics.importStarted(source: source, entry: 'share_sheet');
    Analytics.breadcrumb('import started from $source');
    try {
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

      // Adapt to the user's diet/allergies before saving, so the recipe they
      // land on is already usable. No-ops when they have no restrictions.
      final restrictions = await RecipeAdapter.profileRestrictions();
      var finalRecipe = recipe;
      if (restrictions != null) {
        if (mounted) {
          final label = restrictions.diet != 'None'
              ? restrictions.diet
              : 'your preferences';
          _stageTimer?.cancel();
          setState(() {
            _status = 'Adapting it for $label…';
            _adaptingFor = restrictions.diet != 'None' ? restrictions.diet : label;
          });
        }
        finalRecipe = await RecipeAdapter.adaptOnImport(recipe);
      }

      if (mounted && _adaptingFor != null) setState(() => _adaptingFor = null);
      final recipeId = await FirebaseService.saveRecipe(finalRecipe);
      Analytics.importSucceeded(
        source: source,
        ingredients: finalRecipe.ingredients.length,
        steps: finalRecipe.steps.length,
        seconds: DateTime.now().difference(startedAt).inSeconds,
      );
      MetaAds.recipeImported(source);
      refreshRecipeData(ref); // refresh home screen
      if (mounted) {
        setState(() {
          _saved = finalRecipe.copyWith(id: recipeId);
          _loading = false;
        });
      }
    } on NoRecipeFoundException catch (e) {
      // Platform blocks scraping (Instagram/TikTok login wall, etc.)
      Analytics.importFailed(source: source, reason: 'no_recipe_found');
      if (mounted) {
        setState(() {
          _noRecipeReason = e.reason;
          _loading = false;
        });
      }
    } catch (e, st) {
      Analytics.importFailed(source: source, reason: 'error');
      Analytics.recordError(e, st, context: 'recipe import from $source');
      if (mounted) {
        setState(() {
          _error = friendlyError(e);
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
            ? _ImportingView(
                url: _extractUrl(widget.sharedUrl),
                status: _status,
                adaptingFor: _adaptingFor,
                colors: colors)
            : _outOfImports
                ? _OutOfImportsView(
                    onSeePro: () async {
                      final unlocked =
                          await PlatefulPaywall.forcePresent(context);
                      if (unlocked && mounted) {
                        _import(); // they upgraded, so run the import they wanted
                      }
                    },
                    onClose: _close,
                    colors: colors,
                  )
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

// ── Out of free imports ───────────────────────────────────────────────────────
/// Distinct from [_NoRecipeView]: nothing went wrong with the link, the free
/// allowance is simply spent. Saying so plainly, and naming the link they just
/// shared, is what keeps this from feeling like a bait and switch.
class _OutOfImportsView extends StatelessWidget {
  final Future<void> Function() onSeePro;
  final VoidCallback onClose;
  final AppColorScheme colors;

  const _OutOfImportsView({
    required this.onSeePro,
    required this.onClose,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          24, 32, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome,
                size: 34, color: AppColors.accent),
          )
              .animate()
              .scale(
                  begin: const Offset(0.7, 0.7),
                  duration: 350.ms,
                  curve: Curves.easeOut),
          const SizedBox(height: 20),
          Text(
            'You have used your ${ProLimits.freeImports} free imports',
            style: AppTextStyles.headingMedium,
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 100.ms),
          const SizedBox(height: 10),
          Text(
            'This link was not saved. Every recipe imported from a link is '
            'read and written up by AI, which costs us on each import. '
            'Plateful Pro removes the limit.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: colors.textSecondary, height: 1.55, fontSize: 14),
          ).animate().fadeIn(delay: 150.ms),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onSeePro,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 52),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('See Plateful Pro',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: onClose,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 48),
                foregroundColor: colors.textSecondary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Close',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You can still add recipes by hand for free.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Importing ─────────────────────────────────────────────────────────────────
class _ImportingView extends StatelessWidget {
  final String url;
  final String status;

  /// Non null while the recipe is being rewritten for the user's diet, which
  /// swaps in an animation about substitution rather than about reading.
  final String? adaptingFor;
  final AppColorScheme colors;
  const _ImportingView({
    required this.url,
    required this.status,
    required this.adaptingFor,
    required this.colors,
  });

  String get _host {
    final u = Uri.tryParse(url);
    final h = u?.host.replaceFirst('www.', '') ?? '';
    return h.isEmpty ? url : h;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 3),
          // Reading and adapting are different jobs, so they get different
          // animations. The swap animation also teaches the feature while
          // the user waits for it.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            child: adaptingFor == null
                ? const CookingLoader(key: ValueKey('reading'), size: 160)
                : AdaptingLoader(
                    key: const ValueKey('adapting'),
                    dietLabel: adaptingFor!,
                  ),
          ),
          const SizedBox(height: 36),

          // Live status, cross-fading as the stages progress.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            child: Text(
              status,
              key: ValueKey(status),
              textAlign: TextAlign.center,
              style: AppTextStyles.headingMedium,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.link_rounded, size: 14, color: colors.textSecondary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(_host,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.textSecondary, fontSize: 13)),
              ),
            ],
          ),
          const Spacer(flex: 4),

          // Reassurance while the work happens.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                const IntelligenceGlyph(size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Reading the page, pulling out ingredients and steps, and '
                    'working out the macros.',
                    style: AppTextStyles.caption
                        .copyWith(color: colors.textSecondary, height: 1.4),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 300.ms),
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
  bool get _isYouTube =>
      sharedUrl.contains('youtube.com') || sharedUrl.contains('youtu.be');

  /// True for social posts, where the recipe usually lives in a caption the
  /// user can copy. Plain websites get different guidance.
  bool get _isSocial => _isInstagram || _isTikTok || _isYouTube;

  String? get _platformName {
    if (_isInstagram) return 'Instagram';
    if (_isTikTok) return 'TikTok';
    if (_isYouTube) return 'YouTube';
    return null;
  }

  IconData get _platformIcon {
    if (_isInstagram) return Icons.camera_alt_outlined;
    if (_isTikTok) return Icons.music_video_outlined;
    if (_isYouTube) return Icons.smart_display_outlined;
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

          // Show what actually went wrong, straight from the extractor.
          Text(
            reason,
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
                Text(
                    _isSocial
                        ? 'How to import recipes from $_platformName'
                        : 'What you can try',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: colors.textPrimary)),
                const SizedBox(height: 14),
                if (_isSocial) ...[
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
                ] else ...[
                  _Tip(
                    number: '1',
                    text: 'Check the link opens in a browser and shows a recipe.',
                    colors: colors,
                  ),
                  _Tip(
                    number: '2',
                    text: 'Some pages hide their recipe behind a paywall or pop-up.',
                    colors: colors,
                  ),
                  _Tip(
                    number: '3',
                    text: 'You can always copy the recipe in and add it manually.',
                    colors: colors,
                  ),
                ],
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
              label: Text(_isSocial ? 'Open in $_platformName' : 'Open link'),
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

        // Optional, skippable nudge to organize the recipe into a collection.
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextButton.icon(
              onPressed: () => showCollectionPicker(context, recipe.id),
              icon: const Icon(Icons.collections_bookmark_outlined, size: 18),
              label: const Text('Add to a collection'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
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
