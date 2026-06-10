import 'package:flutter/material.dart';

import '../../core/design/design.dart';

/// Full-screen day detail — also rendered as a bottom sheet from the calendar.
/// Fully implemented in Step 8.
class DayDetailScreen extends StatelessWidget {
  const DayDetailScreen({required this.date, super.key});

  final String date; // YYYY-MM-DD

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(date)),
      body: EmptyState(
        icon: Icons.event_note,
        message: 'Day detail for $date',
        hint: 'Tags, events, meals and more will appear here.',
      ),
    );
  }
}
