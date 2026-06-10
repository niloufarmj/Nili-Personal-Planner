import 'package:flutter/material.dart';

import '../../core/design/design.dart';

/// Track tab — Finance · Meals · Fitness · Gym · Habits · Wellbeing · Work · Social.
/// Fully implemented by Agents 3-4.
class TrackScreen extends StatelessWidget {
  const TrackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Track')),
      body: const EmptyState(
        icon: Icons.bar_chart,
        message: 'Track what matters',
        hint:
            'Finance, meals, gym, habits, wellbeing, work time and more will appear here.',
      ),
    );
  }
}
