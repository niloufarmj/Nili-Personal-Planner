import 'package:flutter/material.dart';

import '../app_colors.dart';

/// Small colored badge for item priority (1=high, 2=normal, 3=low).
class PriorityBadge extends StatelessWidget {
  const PriorityBadge({required this.priority, super.key});

  final int priority;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forPriority(priority);
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
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
