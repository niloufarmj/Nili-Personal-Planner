import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/design.dart';

/// Track tab — Finance · Meals · Fitness · Gym · Habits · Wellbeing · Work · Social.
class TrackScreen extends StatelessWidget {
  const TrackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Track')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _TrackEntry(
            icon: Icons.restaurant,
            title: 'Meals',
            subtitle: 'Weekly meal grid & shopping list',
            route: '/meals',
          ),
        ],
      ),
    );
  }
}

class _TrackEntry extends StatelessWidget {
  const _TrackEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cs.primaryContainer,
          child: Icon(icon, color: cs.onPrimaryContainer),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(route),
      ),
    );
  }
}
