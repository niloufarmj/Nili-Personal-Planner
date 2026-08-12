import 'package:flutter/material.dart';
import 'package:figma_squircle/figma_squircle.dart';
import '../tokens.dart';

/// Themed card wrapper with squircle corners, ambient shadow, and consistent padding.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final resolvedColor =
        color ??
        (isDark ? DesignTokens.surfaceDark : DesignTokens.surfaceLight);
    final lineColor = borderColor ?? (isDark ? DesignTokens.lineDark : DesignTokens.lineLight);
    final inkColor = isDark ? DesignTokens.inkDark : DesignTokens.inkLight;

    final shape = SmoothRectangleBorder(
      side: BorderSide(color: lineColor, width: borderColor != null ? 1.5 : 1),
      borderRadius: const SmoothBorderRadius.all(
        SmoothRadius(
          cornerRadius: DesignTokens.radiusCard,
          cornerSmoothing: 1.0,
        ),
      ),
    );

    return Container(
      decoration: ShapeDecoration(
        color: resolvedColor,
        shape: shape,
        shadows: DesignTokens.shadow(inkColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: SmoothRectangleBorder(
            borderRadius: const SmoothBorderRadius.all(
              SmoothRadius(
                cornerRadius: DesignTokens.radiusCard,
                cornerSmoothing: 1.0,
              ),
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
