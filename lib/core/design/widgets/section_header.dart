import 'package:flutter/material.dart';
import '../tokens.dart';

/// Compact section heading used inside cards and sheets, formatted as overline.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    super.key,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(0, 16, 0, 8),
  });

  final String title;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight;
    final trailingVal = trailing;

    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          if (trailingVal != null) trailingVal,
        ],
      ),
    );
  }
}

