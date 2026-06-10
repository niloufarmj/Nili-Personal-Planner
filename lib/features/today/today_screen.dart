import 'package:flutter/material.dart';

import '../../core/design/design.dart';

/// Today screen — fully implemented in Step 9.
/// Placeholder until the CalendarAggregator and day-layer are wired up.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Today')),
      body: const EmptyState(
        icon: Icons.today,
        message: 'Your day at a glance',
        hint: 'Events, habits, and meals for today will appear here.',
      ),
    );
  }
}
