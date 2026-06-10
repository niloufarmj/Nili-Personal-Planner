import 'package:flutter/material.dart';

import '../../core/design/design.dart';

/// More tab — Travel, Reminders, Partner, Growth, Backup, Settings, Tags editor.
/// Fully implemented by Agent 5 and Step 5 (tag editor).
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: const EmptyState(
        icon: Icons.more_horiz,
        message: 'Everything else',
        hint:
            'Travel planner, reminders, backup, tag manager and settings will appear here.',
      ),
    );
  }
}
