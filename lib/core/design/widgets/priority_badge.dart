import 'package:flutter/material.dart';
import '../tokens.dart';

/// Small colored badge for item priority (1=high, 2=normal, 3=low), styled using DesignTokens.
class PriorityBadge extends StatelessWidget {
  const PriorityBadge({required this.priority, super.key});

  final int priority;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final color = switch (priority) {
      1 => isDark ? DesignTokens.accentDark : DesignTokens.accentLight,
      3 => isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
      _ =>
        isDark
            ? DesignTokens.adjustColorForDark(DesignTokens.dustyBlue)
            : DesignTokens.dustyBlue,
    };

    final label = switch (priority) {
      1 => '↑ High',
      3 => '↓ Low',
      _ => '— Normal',
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }
}
