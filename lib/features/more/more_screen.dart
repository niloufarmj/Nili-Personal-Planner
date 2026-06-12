import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/design.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _MoreEntry(
            icon: Icons.flight_takeoff,
            title: 'Travel Planner',
            subtitle: 'Trips, packing lists & travel budget',
            route: '/trips',
          ),
          SizedBox(height: 12),
          _MoreEntry(
            icon: Icons.notifications_outlined,
            title: 'Reminders',
            subtitle: 'Windowed alerts & recurring nudges',
            route: '/reminders',
          ),
          SizedBox(height: 12),
          _MoreEntry(
            icon: Icons.people_outline,
            title: 'Partner Schedule',
            subtitle: 'Reza\'s tags & shared events',
            route: '/partner',
          ),
        ],
      ),
    );
  }
}

class _MoreEntry extends StatelessWidget {
  const _MoreEntry({
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
