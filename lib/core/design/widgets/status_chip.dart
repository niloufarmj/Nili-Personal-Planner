import 'package:flutter/material.dart';

import '../app_colors.dart';

/// Colored chip representing an item status (open, done, planned, blocked).
class StatusChip extends StatelessWidget {
  const StatusChip({required this.status, super.key, this.compact = false});

  final String status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = _resolve(status);
    return Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static (String, Color, Color) _resolve(String status) => switch (status
      .toLowerCase()) {
    'done' => ('Done', AppColors.statusDone, const Color(0xFF2E7D32)),
    'blocked' => ('Blocked', AppColors.statusBlocked, const Color(0xFFC62828)),
    'planned' || 'suggested' => (
      status[0].toUpperCase() + status.substring(1),
      AppColors.statusPlanned,
      const Color(0xFF1565C0),
    ),
    'in_progress' || 'in-progress' => (
      'In Progress',
      const Color(0xFFFFF9C4),
      const Color(0xFFF57F17),
    ),
    _ => (
      status[0].toUpperCase() + status.substring(1),
      AppColors.statusOpen,
      const Color(0xFF424242),
    ),
  };
}
