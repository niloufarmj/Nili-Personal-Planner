import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/design/design.dart';
import '../../core/router/routes.dart';
import '../../core/services/backup_service.dart';
import '../lists/repositories/collection_repository.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'More',
          style: GoogleFonts.fraunces(
            fontSize: DesignTokens.fontTitle,
            fontWeight: FontWeight.w600,
            color: isDark ? DesignTokens.inkDark : DesignTokens.inkLight,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: [
          const SectionHeader(title: 'Features'),
          const SizedBox(height: 12),
          _MoreEntry(
            icon: Icons.flight_takeoff,
            title: 'Travel Planner',
            subtitle: 'Trips, packing lists & travel budget',
            color: DesignTokens.sage,
            onTap: () => context.push('/trips'),
          ),
          const SizedBox(height: 12),
          _MoreEntry(
            icon: Icons.notifications_outlined,
            title: 'Reminders',
            subtitle: 'Windowed alerts & recurring nudges',
            color: DesignTokens.rose,
            onTap: () => context.push('/reminders'),
          ),
          const SizedBox(height: 12),
          _MoreEntry(
            icon: Icons.people_outline,
            title: 'Partner Schedule',
            subtitle: 'Reza\'s tags & shared events',
            color: DesignTokens.dustyBlue,
            onTap: () => context.push('/partner'),
          ),
          const SizedBox(height: 12),
          _MoreEntry(
            icon: Icons.trending_up,
            title: 'Personal Growth',
            subtitle: 'Track your personal goals & habits',
            color: DesignTokens.lavender,
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
          const SizedBox(height: 28),
          const SectionHeader(title: 'Data Safety'),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: DesignTokens.resolvePastelFill(
                          color: DesignTokens.butter,
                          isDark: isDark,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.backup_outlined,
                        color: isDark ? DesignTokens.inkDark : DesignTokens.inkLight,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Backup & Restore',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? DesignTokens.inkDark : DesignTokens.inkLight,
                                ),
                              ),
                              const SizedBox(width: 8),
                              ref.watch(shouldNudgeProvider).maybeWhen(
                                    data: (nudge) => nudge
                                        ? const _BackupPillWarning()
                                        : const SizedBox.shrink(),
                                    orElse: () => const SizedBox.shrink(),
                                  ),
                            ],
                          ),
                          ref.watch(lastBackupTimeProvider).when(
                                loading: () => Text(
                                  'Loading...',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontSize: DesignTokens.fontCaption,
                                    color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
                                  ),
                                ),
                                error: (err, stack) => Text(
                                  'Error loading time',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontSize: DesignTokens.fontCaption,
                                    color: DesignTokens.danger,
                                  ),
                                ),
                                data: (time) {
                                  final text = time == null
                                      ? 'Last backup: Never'
                                      : 'Last backup: ${DateFormat('yyyy-MM-dd HH:mm').format(time)}';
                                  return Text(
                                    text,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontSize: DesignTokens.fontCaption,
                                      color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
                                    ),
                                  );
                                },
                              ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.share, size: 18),
                        label: const Text('Export Zip'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? DesignTokens.accentDark : DesignTokens.accentLight,
                          side: BorderSide(
                            color: isDark ? DesignTokens.accentDark.withValues(alpha: 0.5) : DesignTokens.accentLight.withValues(alpha: 0.5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () async {
                          try {
                            await ref
                                .read(backupServiceProvider)
                                .exportAndShare();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Backup created & shared!'),
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
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? DesignTokens.accentDark : DesignTokens.accentLight,
                          side: BorderSide(
                            color: isDark ? DesignTokens.accentDark.withValues(alpha: 0.5) : DesignTokens.accentLight.withValues(alpha: 0.5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
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
          const SizedBox(height: 28),
          const SectionHeader(title: 'App Settings'),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: DropdownButtonHideUnderline(
              child: DropdownButtonFormField<ThemeMode>(
                initialValue: themeMode,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? DesignTokens.inkDark : DesignTokens.inkLight,
                ),
                decoration: InputDecoration(
                  labelText: 'Theme Mode',
                  labelStyle: TextStyle(
                    color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
                    fontSize: DesignTokens.fontCaption,
                  ),
                  border: InputBorder.none,
                ),
                dropdownColor: isDark ? DesignTokens.surfaceDark : DesignTokens.surfaceLight,
                items: [
                  DropdownMenuItem(
                    value: ThemeMode.system,
                    child: Text(
                      'System Default',
                      style: TextStyle(
                        color: isDark ? DesignTokens.inkDark : DesignTokens.inkLight,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.light,
                    child: Text(
                      'Light Mode',
                      style: TextStyle(
                        color: isDark ? DesignTokens.inkDark : DesignTokens.inkLight,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.dark,
                    child: Text(
                      'Dark Mode',
                      style: TextStyle(
                        color: isDark ? DesignTokens.inkDark : DesignTokens.inkLight,
                      ),
                    ),
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
          const _MoreFooter(),
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
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final badgeBg = DesignTokens.resolvePastelFill(color: color, isDark: isDark);
    final iconColor = isDark ? DesignTokens.inkDark : DesignTokens.inkLight;

    return AppCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: badgeBg,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: DesignTokens.fontBody,
            color: isDark ? DesignTokens.inkDark : DesignTokens.inkLight,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: DesignTokens.fontCaption,
            color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
        ),
        onTap: onTap,
      ),
    );
  }
}

class _BackupPillWarning extends StatelessWidget {
  const _BackupPillWarning();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isDark
            ? DesignTokens.danger.withValues(alpha: 0.18)
            : DesignTokens.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: DesignTokens.danger.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Text(
        'NEEDS BACKUP',
        style: theme.textTheme.labelSmall?.copyWith(
          color: DesignTokens.danger,
          fontWeight: FontWeight.w700,
          fontSize: 9,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _MoreFooter extends ConsumerWidget {
  const _MoreFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final lastBackupTime = ref.watch(lastBackupTimeProvider).value;
    final needsBackup = ref.watch(shouldNudgeProvider).value ?? false;

    const versionStr = 'Version 1.0.0';
    final backupStatusStr = lastBackupTime == null
        ? 'Never backed up'
        : 'Last backup: ${DateFormat('yyyy-MM-dd HH:mm').format(lastBackupTime)}';

    return Center(
      child: Column(
        children: [
          Text(
            versionStr,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
              fontSize: DesignTokens.fontCaption,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            backupStatusStr,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
              fontSize: DesignTokens.fontCaption,
            ),
          ),
          if (needsBackup) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDark
                    ? DesignTokens.danger.withValues(alpha: 0.18)
                    : DesignTokens.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: DesignTokens.danger.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 14,
                    color: DesignTokens.danger,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Backup Nudge: Past 30 days',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: DesignTokens.danger,
                      fontWeight: FontWeight.w600,
                      fontSize: DesignTokens.fontCaption - 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
