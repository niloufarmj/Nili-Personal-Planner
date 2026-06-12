import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/design/design.dart';
import '../../core/router/routes.dart';
import '../../core/services/backup_service.dart';
import '../lists/repositories/collection_repository.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionHeader(title: 'Features'),
          const SizedBox(height: 8),
          _MoreEntry(
            icon: Icons.flight_takeoff,
            title: 'Travel Planner',
            subtitle: 'Trips, packing lists & travel budget',
            onTap: () => context.push('/trips'),
          ),
          const SizedBox(height: 12),
          _MoreEntry(
            icon: Icons.notifications_outlined,
            title: 'Reminders',
            subtitle: 'Windowed alerts & recurring nudges',
            onTap: () => context.push('/reminders'),
          ),
          const SizedBox(height: 12),
          _MoreEntry(
            icon: Icons.people_outline,
            title: 'Partner Schedule',
            subtitle: 'Reza\'s tags & shared events',
            onTap: () => context.push('/partner'),
          ),
          const SizedBox(height: 12),
          _MoreEntry(
            icon: Icons.trending_up,
            title: 'Personal Growth',
            subtitle: 'Track your personal goals & habits',
            onTap: () async {
              final collection = await ref
                  .read(collectionRepositoryProvider)
                  .getByTemplate('growth');
              if (collection != null && context.mounted) {
                context.push(Routes.collectionPath(collection.id));
              } else if (context.mounted) {
                context.go('/lists');
              }
            },
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Data Safety'),
          const SizedBox(height: 8),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(
                        Icons.backup_outlined,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Backup & Restore',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          ref.watch(lastBackupTimeProvider).when(
                            loading: () => const Text(
                              'Loading...',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            error: (_, __) => const Text(
                              'Error loading time',
                              style: TextStyle(fontSize: 12, color: Colors.red),
                            ),
                            data: (time) {
                              if (time == null) {
                                return const Text(
                                  'Last backup: Never',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                );
                              }
                              final formatted = DateFormat('yyyy-MM-dd HH:mm').format(time);
                              return Text(
                                'Last backup: $formatted',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.share, size: 18),
                        label: const Text('Export Zip'),
                        onPressed: () async {
                          try {
                            final path = await ref
                                .read(backupServiceProvider)
                                .exportAndShare();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Backup created & shared!',
                                  ),
                                ),
                              );
                            }
                            ref.invalidate(lastBackupTimeProvider);
                            ref.invalidate(shouldNudgeProvider);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Export failed: $e')),
                              );
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.download, size: 18),
                        label: const Text('Restore Zip'),
                        onPressed: () async {
                          final confirmed = await ConfirmDialog.show(
                            context,
                            title: 'Restore Backup?',
                            message:
                                'This will replace your current database and images. Are you sure?',
                            confirmLabel: 'Restore',
                          );
                          if (confirmed == true && context.mounted) {
                            try {
                              final success = await ref
                                  .read(backupServiceProvider)
                                  .importFromPicker();
                              if (success && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Backup restored! Please restart the app.',
                                    ),
                                  ),
                                );
                                ref.invalidate(lastBackupTimeProvider);
                                ref.invalidate(shouldNudgeProvider);
                              } else if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Restore cancelled or failed.'),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Restore failed: $e')),
                                );
                              }
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'App Settings'),
          const SizedBox(height: 8),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: DropdownButtonHideUnderline(
              child: DropdownButtonFormField<ThemeMode>(
                value: themeMode,
                decoration: const InputDecoration(
                  labelText: 'Theme Mode',
                  border: InputBorder.none,
                ),
                items: const [
                  DropdownMenuItem(
                    value: ThemeMode.system,
                    child: Text('System Default'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.light,
                    child: Text('Light Mode'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.dark,
                    child: Text('Dark Mode'),
                  ),
                ],
                onChanged: (mode) {
                  if (mode != null) {
                    ref.read(themeModeProvider.notifier).setThemeMode(mode);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 40),
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
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

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
        onTap: onTap,
      ),
    );
  }
}
