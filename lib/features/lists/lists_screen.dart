import 'package:flutter/material.dart';

import '../../core/design/design.dart';

/// Lists tab — fully implemented by Agent 2 (list engine).
class ListsScreen extends StatelessWidget {
  const ListsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lists')),
      body: const EmptyState(
        icon: Icons.checklist,
        message: 'All your lists in one place',
        hint:
            'Shopping, chores, uni tasks, job hunt and more — tap + to create a list.',
      ),
    );
  }
}
