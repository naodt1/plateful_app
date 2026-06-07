import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_colors.dart';

class SkeletonLoader extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Shimmer.fromColors(
      baseColor: colors.surface,
      highlightColor: colors.border,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class SkeletonRecipeCard extends StatelessWidget {
  const SkeletonRecipeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonLoader(width: 200, height: 140, borderRadius: 16),
          const SizedBox(height: 8),
          SkeletonLoader(width: 160, height: 14, borderRadius: 4),
          const SizedBox(height: 4),
          SkeletonLoader(width: 100, height: 12, borderRadius: 4),
        ],
      ),
    );
  }
}

class SkeletonListItem extends StatelessWidget {
  const SkeletonListItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SkeletonLoader(width: 56, height: 56, borderRadius: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(
                    width: double.infinity, height: 14, borderRadius: 4),
                const SizedBox(height: 6),
                SkeletonLoader(width: 120, height: 12, borderRadius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SkeletonText extends StatelessWidget {
  final double width;
  final double height;

  const SkeletonText({super.key, required this.width, this.height = 14});

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(width: width, height: height, borderRadius: 4);
  }
}
