import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// A shimmer skeleton placeholder for loading states.
/// Use [AppSkeletonLoader] for a full-screen skeleton grid,
/// or [AppSkeleton] for individual placeholder shapes.
class AppSkeleton extends StatelessWidget {
  final double? width;
  final double? height;
  final double radius;

  const AppSkeleton({
    super.key,
    this.width,
    this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Full-screen skeleton loader with multiple placeholder rows/columns.
class AppSkeletonLoader extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final double itemWidth;
  final double spacing;

  const AppSkeletonLoader({
    super.key,
    this.itemCount = 8,
    this.itemHeight = 72,
    this.itemWidth = double.infinity,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: DesignTokens.hPadding16,
      itemCount: itemCount,
      itemBuilder: (_, __) => Padding(
        padding: EdgeInsets.only(bottom: spacing),
        child: AppSkeleton(width: itemWidth, height: itemHeight, radius: 16),
      ),
    );
  }
}
