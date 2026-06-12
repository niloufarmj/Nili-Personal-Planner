import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// A pulsing placeholder component to display during content loading states.
class ShimmerSkeleton extends StatelessWidget {
  const ShimmerSkeleton({
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
    super.key,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Warm, desaturated tones matching the planner's light/dark colors
    final base = isDark ? const Color(0xFF423B49) : const Color(0xFFEBE3E0);
    final highlight = isDark
        ? const Color(0xFF554D5D)
        : const Color(0xFFF7F2F0);

    final disableAnimations = MediaQuery.of(context).disableAnimations;
    if (disableAnimations) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      );
    }

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}
