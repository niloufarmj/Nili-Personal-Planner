import 'package:flutter/material.dart';

import '../../core/design/design.dart';

/// Main calendar screen — fully implemented in Step 8.
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: const EmptyState(
        icon: Icons.calendar_month,
        message: 'Your life on one calendar',
        hint: 'Events, trips, gym sessions and more will appear here.',
      ),
    );
  }
}
