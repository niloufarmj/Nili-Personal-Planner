import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/design/design.dart';
import '../../core/router/routes.dart';
import '../../core/services/backup_service.dart';
import '../lists/repositories/collection_repository.dart';
import '../settings/seed/services/seeder_service.dart';

final _seedingProgressProvider = StateProvider<bool>((ref) => false);

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeMode = ref.watch(themeModeProvider);
    final isSeeding = ref.watch(_seedingProgressProvider);

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
      body: Stack(
        children: [
          ListView(
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
                            color: isDark
                                ? DesignTokens.inkDark
                                : DesignTokens.inkLight,
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
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? DesignTokens.inkDark
                                              : DesignTokens.inkLight,
                                        ),
                                  ),
                                  const SizedBox(width: 8),
                                  ref
                                      .watch(shouldNudgeProvider)
                                      .maybeWhen(
                                        data: (nudge) => nudge
                                            ? const _BackupPillWarning()
                                            : const SizedBox.shrink(),
                                        orElse: () => const SizedBox.shrink(),
                                      ),
                                ],
                              ),
                              ref
                                  .watch(lastBackupTimeProvider)
                                  .when(
                                    loading: () => Text(
                                      'Loading...',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontSize: DesignTokens.fontCaption,
                                            color: isDark
                                                ? DesignTokens.inkSoftDark
                                                : DesignTokens.inkSoftLight,
                                          ),
                                    ),
                                    error: (err, stack) => Text(
                                      'Error loading time',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
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
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontSize:
                                                  DesignTokens.fontCaption,
                                              color: isDark
                                                  ? DesignTokens.inkSoftDark
                                                  : DesignTokens.inkSoftLight,
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
                              foregroundColor: isDark
                                  ? DesignTokens.accentDark
                                  : DesignTokens.accentLight,
                              side: BorderSide(
                                color: isDark
                                    ? DesignTokens.accentDark.withValues(
                                        alpha: 0.5,
                                      )
                                    : DesignTokens.accentLight.withValues(
                                        alpha: 0.5,
                                      ),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  DesignTokens.radiusInput,
                                ),
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
                                    SnackBar(
                                      content: Text('Export failed: $e'),
                                    ),
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
                              foregroundColor: isDark
                                  ? DesignTokens.accentDark
                                  : DesignTokens.accentLight,
                              side: BorderSide(
                                color: isDark
                                    ? DesignTokens.accentDark.withValues(
                                        alpha: 0.5,
                                      )
                                    : DesignTokens.accentLight.withValues(
                                        alpha: 0.5,
                                      ),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  DesignTokens.radiusInput,
                                ),
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
                                        content: Text(
                                          'Restore cancelled or failed.',
                                        ),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Restore failed: $e'),
                                      ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButtonFormField<ThemeMode>(
                    initialValue: themeMode,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? DesignTokens.inkDark
                          : DesignTokens.inkLight,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Theme Mode',
                      labelStyle: TextStyle(
                        color: isDark
                            ? DesignTokens.inkSoftDark
                            : DesignTokens.inkSoftLight,
                        fontSize: DesignTokens.fontCaption,
                      ),
                      border: InputBorder.none,
                    ),
                    dropdownColor: isDark
                        ? DesignTokens.surfaceDark
                        : DesignTokens.surfaceLight,
                    items: [
                      DropdownMenuItem(
                        value: ThemeMode.system,
                        child: Text(
                          'System Default',
                          style: TextStyle(
                            color: isDark
                                ? DesignTokens.inkDark
                                : DesignTokens.inkLight,
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.light,
                        child: Text(
                          'Light Mode',
                          style: TextStyle(
                            color: isDark
                                ? DesignTokens.inkDark
                                : DesignTokens.inkLight,
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.dark,
                        child: Text(
                          'Dark Mode',
                          style: TextStyle(
                            color: isDark
                                ? DesignTokens.inkDark
                                : DesignTokens.inkLight,
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
              if (ref.watch(debugSeedingEnabledProvider)) ...[
                const SizedBox(height: 28),
                const SectionHeader(title: 'Debug Tools'),
                const SizedBox(height: 12),
                _MoreEntry(
                  icon: Icons.data_usage_rounded,
                  title: 'Load seed data',
                  subtitle: 'Populate app with initial seed data',
                  color: DesignTokens.butter,
                  onTap: () => _handleLoadSeed(context, ref),
                ),
              ],
              const SizedBox(height: 40),
              const _MoreFooter(),
              const SizedBox(height: 40),
            ],
          ),
          if (isSeeding)
            Container(
              color: Colors.black.withValues(alpha: 0.4),
              child: Center(
                child: AppCard(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'Seeding database...',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark
                              ? DesignTokens.inkDark
                              : DesignTokens.inkLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleLoadSeed(BuildContext context, WidgetRef ref) async {
    final assetBundle = DefaultAssetBundle.of(context);
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Load Seed Data?',
      message:
          'This will load Persian workout programs, movies, shopping lists, and habits. Pre-existing user data will not be modified. Proceed?',
      confirmLabel: 'Load',
    );
    if (confirmed != true) return;

    try {
      ref.read(_seedingProgressProvider.notifier).state = true;

      final jsonStr = await assetBundle.loadString('assets/seeds/seed.json');
      final summary = await ref.read(seederServiceProvider).run(jsonStr);

      ref.read(_seedingProgressProvider.notifier).state = false;

      if (summary.alreadySeeded) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Already seeded (v1)')));
        }
      } else {
        if (context.mounted) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (context) => _SeedSummarySheet(summary: summary),
          );
        }
      }
    } catch (e) {
      ref.read(_seedingProgressProvider.notifier).state = false;
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading seed data: $e')));
      }
    }
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
    final badgeBg = DesignTokens.resolvePastelFill(
      color: color,
      isDark: isDark,
    );
    final iconColor = isDark ? DesignTokens.inkDark : DesignTokens.inkLight;

    return AppCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: badgeBg, shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 20),
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
            color: isDark
                ? DesignTokens.inkSoftDark
                : DesignTokens.inkSoftLight,
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
              color: isDark
                  ? DesignTokens.inkSoftDark
                  : DesignTokens.inkSoftLight,
              fontSize: DesignTokens.fontCaption,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            backupStatusStr,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark
                  ? DesignTokens.inkSoftDark
                  : DesignTokens.inkSoftLight,
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

class _SeedSummarySheet extends StatelessWidget {
  final SeedSummary summary;

  const _SeedSummarySheet({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark
                ? DesignTokens.surfaceDark
                : DesignTokens.surfaceLight,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Seed Data Summary',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? DesignTokens.inkDark : DesignTokens.inkLight,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _buildSummaryRow(
                      context,
                      'Tags',
                      summary.tagsInserted,
                      summary.tagsUpdated,
                      summary.tagsSkipped,
                    ),
                    _buildSummaryRow(
                      context,
                      'Collections',
                      summary.collectionsInserted,
                      summary.collectionsUpdated,
                      summary.collectionsSkipped,
                    ),
                    _buildSummaryRow(
                      context,
                      'Items',
                      summary.itemsInserted,
                      summary.itemsUpdated,
                      summary.itemsSkipped,
                    ),
                    _buildSummaryRow(
                      context,
                      'Ingredients',
                      summary.ingredientsInserted,
                      summary.ingredientsUpdated,
                      summary.ingredientsSkipped,
                    ),
                    _buildSummaryRow(
                      context,
                      'Workout Plans',
                      summary.plansInserted,
                      summary.plansUpdated,
                      summary.plansSkipped,
                    ),
                    _buildSummaryRow(
                      context,
                      'Measurements',
                      summary.measurementsInserted,
                      summary.measurementsUpdated,
                      summary.measurementsSkipped,
                    ),
                    _buildSummaryRow(
                      context,
                      'Fitness Goals',
                      summary.goalsInserted,
                      summary.goalsUpdated,
                      summary.goalsSkipped,
                    ),
                    _buildSummaryRow(
                      context,
                      'Habits',
                      summary.habitsInserted,
                      summary.habitsUpdated,
                      summary.habitsSkipped,
                    ),
                    _buildSummaryRow(
                      context,
                      'Debts',
                      summary.debtsInserted,
                      summary.debtsUpdated,
                      summary.debtsSkipped,
                    ),
                    if (summary.warnings.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Warnings & Skipped Items',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: DesignTokens.danger,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...summary.warnings.map(
                        (w) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            '• $w',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark
                                  ? DesignTokens.inkSoftDark
                                  : DesignTokens.inkSoftLight,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? DesignTokens.accentDark
                      : DesignTokens.accentLight,
                  foregroundColor: isDark
                      ? DesignTokens.surfaceDark
                      : DesignTokens.surfaceLight,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      DesignTokens.radiusInput,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow(
    BuildContext context,
    String title,
    int inserted,
    int updated, [
    int skipped = 0,
  ]) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? DesignTokens.inkDark : DesignTokens.inkLight,
            ),
          ),
          Text(
            skipped > 0
                ? '+$inserted ins, $updated upd, $skipped skip'
                : '+$inserted ins, $updated upd',
            style: textStyle,
          ),
        ],
      ),
    );
  }
}
