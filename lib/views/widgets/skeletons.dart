// lib/views/widgets/skeletons.dart
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Bloc shimmer arrondi de base.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
      highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Skeleton de la rangée d'icônes de catégories, dans le header vert.
///
/// Le shimmer est éclairci : il s'affiche sur le vert primaire, pas sur le
/// fond gris clair des autres skeletons.
class CategoryIconsSkeleton extends StatelessWidget {
  final int count;

  const CategoryIconsSkeleton({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.white.withOpacity(0.25),
      highlightColor: Colors.white.withOpacity(0.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          count,
          (_) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5.5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 34,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Skeleton de la page d'accueil : carrousel + sections horizontales.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(height: 190, radius: 24),
          const SizedBox(height: 20),
          const SkeletonBox(width: 160, height: 22, radius: 8),
          const SizedBox(height: 10),
          _cardsRow(),
          const SizedBox(height: 20),
          const SkeletonBox(width: 130, height: 22, radius: 8),
          const SizedBox(height: 10),
          _cardsRow(),
        ],
      ),
    );
  }

  Widget _cardsRow() {
    return SizedBox(
      height: 220,
      child: Row(
        children: const [
          Expanded(child: SkeletonBox(height: 220, radius: 24)),
          SizedBox(width: 10),
          Expanded(child: SkeletonBox(height: 220, radius: 24)),
        ],
      ),
    );
  }
}

/// Skeleton d'une liste verticale de cartes (catégories, favoris).
class ListSkeleton extends StatelessWidget {
  final int itemCount;
  final double itemHeight;

  const ListSkeleton({super.key, this.itemCount = 4, this.itemHeight = 240});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: itemCount,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: SkeletonBox(height: itemHeight, radius: 24),
      ),
    );
  }
}
