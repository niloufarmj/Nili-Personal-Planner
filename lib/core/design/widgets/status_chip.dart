import 'package:flutter/material.dart';
import '../tokens.dart';

/// Colored chip representing an item status (open, done, planned, blocked), complying with WCAG AA contrast.
class StatusChip extends StatelessWidget {
  const StatusChip({required this.status, super.key, this.compact = false});

  final String status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final (label, baseColor) = _resolve(status);
    final bg = DesignTokens.resolvePastelFill(color: baseColor, isDark: isDark);
    final fg = isDark ? DesignTokens.inkDark : DesignTokens.inkLight;

    return Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 2)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
        border: Border.all(
          color: isDark ? DesignTokens.lineDark : DesignTokens.lineLight,
          width: 1,
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  static (String, Color) _resolve(String status) => switch (status.toLowerCase()) {
    'done' => ('Done', DesignTokens.success),
    'blocked' => ('Blocked', DesignTokens.danger),
    'planned' || 'suggested' => (
      status[0].toUpperCase() + status.substring(1),
      DesignTokens.dustyBlue,
    ),
    'in_progress' || 'in-progress' => (
      'In Progress',
      DesignTokens.butter,
    ),
    _ => (
      status[0].toUpperCase() + status.substring(1),
      DesignTokens.inkSoftLight,
    ),
  };
}

