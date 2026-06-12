import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/design.dart';

/// Track tab — Finance · Work Time · Social · Gym · Fitness · Habits · Wellbeing · Meals.
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
            icon: Icons.account_balance_wallet,
            title: 'Finance',
            subtitle: 'Transactions, budget forecast & debts',
            route: '/finance',
          ),
          SizedBox(height: 12),
          _TrackEntry(
            icon: Icons.access_time,
            title: 'Work Time',
            subtitle: 'Log hours, run timer & track overtime',
            route: '/worktime',
          ),
          SizedBox(height: 12),
          _TrackEntry(
            icon: Icons.share,
            title: 'Social',
            subtitle: 'Social media usage & post streaks',
            route: '/social',
          ),
          SizedBox(height: 12),
          _TrackEntry(
            icon: Icons.fitness_center,
            title: 'Gym',
            subtitle: 'Sessions, plans & attendance',
            route: '/gym',
          ),
          SizedBox(height: 12),
          _TrackEntry(
            icon: Icons.monitor_weight_outlined,
            title: 'Fitness',
            subtitle: 'Measurements, goals & charts',
            route: '/fitness',
          ),
          SizedBox(height: 12),
          _TrackEntry(
            icon: Icons.water_drop_outlined,
            title: 'Habits',
            subtitle: 'Water, skincare, reading & more',
            route: '/habits',
          ),
          SizedBox(height: 12),
          _TrackEntry(
            icon: Icons.self_improvement,
            title: 'Feeling Better',
            subtitle: 'Self-care actions & history',
            route: '/wellbeing',
          ),
          SizedBox(height: 12),
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
