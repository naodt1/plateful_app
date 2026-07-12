import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../models/recipe.dart';

class RecipeCard extends StatefulWidget {
  final Recipe recipe;
  final VoidCallback? onTap;

  const RecipeCard({super.key, required this.recipe, this.onTap});

  @override
  State<RecipeCard> createState() => _RecipeCardState();
}

class _RecipeCardState extends State<RecipeCard> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (mounted) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final recipe = widget.recipe;
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Hero(
                    tag: 'recipe-image-${recipe.id}',
                    child: _RecipeImage(imageUrl: recipe.imageUrl),
                  ),
                ),
                if (recipe.favorite)
                  const Positioned(top: 8, right: 8, child: FavoriteHeart()),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        recipe.title,
                        style: AppTextStyles.labelLarge,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _SourceBadge(sourceType: recipe.sourceType),
                        const Spacer(),
                        if (recipe.tags.isNotEmpty)
                          _TagChip(tag: recipe.tags.first),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    ).animate().fadeIn(duration: 350.ms).slideX(
          begin: 0.06,
          end: 0,
          duration: 350.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

class _RecipeImage extends StatelessWidget {
  final String? imageUrl;

  const _RecipeImage({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return Container(
        height: 130,
        color: AppColors.of(context).surface,
        child: const Center(
          child: Icon(Icons.restaurant, size: 40, color: AppColors.primary),
        ),
      );
    }
    return Stack(
      children: [
        CachedNetworkImage(
          imageUrl: imageUrl!,
          height: 130,
          width: double.infinity,
          fit: BoxFit.cover,
          fadeInDuration: const Duration(milliseconds: 350),
          fadeOutDuration: const Duration(milliseconds: 150),
          placeholder: (_, __) => const SkeletonLoader(
              width: double.infinity, height: 130, borderRadius: 0),
          errorWidget: (_, __, ___) => Container(
            height: 130,
            color: AppColors.of(context).surface,
            child: const Center(
              child: Icon(Icons.restaurant, size: 40, color: AppColors.primary),
            ),
          ),
        ),
        // Subtle dark gradient at the bottom for depth + text legibility.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.18),
                ],
                stops: const [0.6, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final String sourceType;

  const _SourceBadge({required this.sourceType});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final icon = switch (sourceType) {
      'link' => Icons.link,
      'share' => Icons.share,
      _ => Icons.edit_outlined,
    };
    final label = switch (sourceType) {
      'link' => 'Link',
      'share' => 'Shared',
      _ => 'Manual',
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: colors.textSecondary),
        const SizedBox(width: 3),
        Text(label, style: AppTextStyles.caption.copyWith(color: colors.textSecondary)),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  final String tag;

  const _TagChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.border,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        tag,
        style: TextStyle(
          fontSize: 10,
          color: colors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class RecipeListCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback? onTap;

  const RecipeListCard({super.key, required this.recipe, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _RecipeImageSmall(imageUrl: recipe.imageUrl),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    style: AppTextStyles.labelLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    recipe.description,
                    style: AppTextStyles.bodySmall.copyWith(color: colors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  _SourceBadge(sourceType: recipe.sourceType),
                ],
              ),
            ),
            if (recipe.favorite) ...[
              const Icon(Icons.favorite, size: 15, color: Color(0xFFE5533D)),
              const SizedBox(width: 8),
            ],
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// A filled heart badge shown on favorited recipe images.
class FavoriteHeart extends StatelessWidget {
  final double size;
  const FavoriteHeart({super.key, this.size = 26});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.favorite,
          size: size * 0.56, color: const Color(0xFFE5533D)),
    );
  }
}

class _RecipeImageSmall extends StatelessWidget {
  final String? imageUrl;

  const _RecipeImageSmall({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return Container(
        width: 64,
        height: 64,
        color: AppColors.of(context).surface,
        child: const Icon(Icons.restaurant, size: 28, color: AppColors.primary),
      );
    }
    return CachedNetworkImage(
      imageUrl: imageUrl!,
      width: 64,
      height: 64,
      fit: BoxFit.cover,
      placeholder: (_, __) =>
          const SkeletonLoader(width: 64, height: 64, borderRadius: 12),
      errorWidget: (_, __, ___) => Container(
        width: 64,
        height: 64,
        color: AppColors.of(context).surface,
        child: const Icon(Icons.restaurant, size: 28, color: AppColors.primary),
      ),
    );
  }
}
