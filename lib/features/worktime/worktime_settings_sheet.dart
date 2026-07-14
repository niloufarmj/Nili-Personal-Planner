import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/db/database.dart';
import '../../core/design/design.dart';
import 'repositories/worktime_repository.dart';

class WorktimeSettingsSheet extends ConsumerStatefulWidget {
  const WorktimeSettingsSheet({super.key});

  @override
  ConsumerState<WorktimeSettingsSheet> createState() => _WorktimeSettingsSheetState();
}

class _WorktimeSettingsSheetState extends ConsumerState<WorktimeSettingsSheet> {
  final _formKey = GlobalKey<FormState>();
  final _baselineCtrl = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final repo = ref.read(worktimeRepositoryProvider);
    final baseline = await repo.getBaselineHoursPerWeek();
    if (mounted) {
      setState(() {
        _baselineCtrl.text = baseline.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _baselineCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inkColor = isDark ? DesignTokens.inkDark : DesignTokens.inkLight;
    final insets = MediaQuery.viewInsetsOf(context);
    final contextsAsync = ref.watch(workContextsProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + insets.bottom),
      child: _loading
          ? const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          : Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Work Settings',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontFamily: GoogleFonts.fraunces().fontFamily,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Baseline Hours Field
                  TextFormField(
                    controller: _baselineCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Baseline Hours / Week',
                      helperText: 'Default target work hours per week',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n <= 0 || n > 168) {
                        return 'Enter a valid number of hours (1 - 168)';
                      }
                      return null;
                    },
                    onChanged: (val) {
                      if (_formKey.currentState!.validate()) {
                        final hours = int.parse(val);
                        ref.read(worktimeRepositoryProvider).setBaselineHoursPerWeek(hours);
                      }
                    },
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Manage Positions',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: inkColor,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // List of positions
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 250),
                    child: contextsAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, _) => Text('Error: $err'),
                      data: (contexts) {
                        if (contexts.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'No jobs defined yet.',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          );
                        }

                        return ListView.separated(
                          shrinkWrap: true,
                          itemCount: contexts.length,
                          separatorBuilder: (_, __) => Divider(
                            color: isDark ? DesignTokens.lineDark : Colors.grey.shade200,
                          ),
                          itemBuilder: (context, idx) {
                            final c = contexts[idx];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                c.name,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: inkColor,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 20),
                                    onPressed: () => _showEditJobDialog(c),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 20),
                                    color: DesignTokens.danger,
                                    onPressed: () => _deleteJob(c),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Add Position Button
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Position'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: isDark ? DesignTokens.accentDark : DesignTokens.accentLight,
                      ),
                      foregroundColor: isDark ? DesignTokens.accentDark : DesignTokens.accentLight,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
                      ),
                    ),
                    onPressed: _showAddJobDialog,
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _showAddJobDialog() async {
    final ctrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Position'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Position Name',
            hintText: 'e.g. FreshFX, Tutoring',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: isDark ? DesignTokens.accentDark : DesignTokens.accentLight,
            ),
            child: const Text('Add'),
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                Navigator.of(ctx).pop(ctrl.text.trim());
              }
            },
          ),
        ],
      ),
    );

    if (name != null) {
      await ref.read(worktimeRepositoryProvider).createContext(name);
    }
  }

  Future<void> _showEditJobDialog(WorkContext job) async {
    final ctrl = TextEditingController(text: job.name);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Position'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Position Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: isDark ? DesignTokens.accentDark : DesignTokens.accentLight,
            ),
            child: const Text('Save'),
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                Navigator.of(ctx).pop(ctrl.text.trim());
              }
            },
          ),
        ],
      ),
    );

    if (name != null && name != job.name) {
      final updated = WorkContext(id: job.id, name: name, color: job.color);
      await ref.read(worktimeRepositoryProvider).updateContext(updated);
    }
  }

  Future<void> _deleteJob(WorkContext job) async {
    final repo = ref.read(worktimeRepositoryProvider);
    final count = await repo.getEntryCountForContext(job.id);

    if (mounted) {
      bool confirm = false;
      if (count > 0) {
        confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete Position?'),
                content: Text(
                  'This position has $count logged session(s). '
                  'Deleting it will permanently delete all of its logged hours. '
                  'Are you sure you want to proceed?',
                ),
                actions: [
                  TextButton(
                    child: const Text('Cancel'),
                    onPressed: () => Navigator.of(ctx).pop(false),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: DesignTokens.danger),
                    child: const Text('Delete All', style: TextStyle(color: Colors.white)),
                    onPressed: () => Navigator.of(ctx).pop(true),
                  ),
                ],
              ),
            ) ??
            false;
      } else {
        confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete Position?'),
                content: Text('Are you sure you want to delete "${job.name}"?'),
                actions: [
                  TextButton(
                    child: const Text('Cancel'),
                    onPressed: () => Navigator.of(ctx).pop(false),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: DesignTokens.danger),
                    child: const Text('Delete', style: TextStyle(color: Colors.white)),
                    onPressed: () => Navigator.of(ctx).pop(true),
                  ),
                ],
              ),
            ) ??
            false;
      }

      if (confirm) {
        await repo.deleteContextAndEntries(job.id);
      }
    }
  }
}
