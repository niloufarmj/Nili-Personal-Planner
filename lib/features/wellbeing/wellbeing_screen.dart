import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/db/database.dart';
import '../../core/design/design.dart';
import 'wellbeing_repository.dart';

final _activeActionsProvider = StreamProvider.autoDispose((ref) {
  return ref.watch(wellbeingRepositoryProvider).watchActiveActions();
});

final _logsForDateProvider = StreamProvider.autoDispose
    .family<List<WellbeingLog>, String>((ref, dateStr) {
      return ref.watch(wellbeingRepositoryProvider).watchLogsForDate(dateStr);
    });

final _dailyLogCountsProvider = StreamProvider.autoDispose((ref) {
  return ref.watch(wellbeingRepositoryProvider).watchDailyLogCounts();
});

/// Emoji and pastel accent color helper for self-care actions.
(String emoji, Color color) _getSelfCareMeta(String name) {
  final l = name.toLowerCase();
  if (l.contains('meditat') || l.contains('mindful') || l.contains('yoga')) {
    return ('🧘', DesignTokens.lavender);
  }
  if (l.contains('friend') ||
      l.contains('talk') ||
      l.contains('call') ||
      l.contains('chat')) {
    return ('💬', DesignTokens.dustyBlue);
  }
  if (l.contains('music') ||
      l.contains('song') ||
      l.contains('listen') ||
      l.contains('podcast')) {
    return ('🎧', DesignTokens.rose);
  }
  if (l.contains('read') ||
      l.contains('book') ||
      l.contains('page') ||
      l.contains('journal')) {
    return ('📖', DesignTokens.sage);
  }
  if (l.contains('walk') ||
      l.contains('run') ||
      l.contains('nature') ||
      l.contains('park')) {
    return ('🌿', DesignTokens.sage);
  }
  if (l.contains('tea') ||
      l.contains('coffee') ||
      l.contains('water') ||
      l.contains('drink')) {
    return ('☕', DesignTokens.peach);
  }
  if (l.contains('sleep') ||
      l.contains('nap') ||
      l.contains('rest') ||
      l.contains('bed')) {
    return ('😴', DesignTokens.lavender);
  }
  if (l.contains('skin') ||
      l.contains('bath') ||
      l.contains('care') ||
      l.contains('shower')) {
    return ('✨', DesignTokens.blush);
  }
  return ('💖', DesignTokens.rose);
}

class WellbeingScreen extends ConsumerStatefulWidget {
  const WellbeingScreen({super.key});

  @override
  ConsumerState<WellbeingScreen> createState() => _WellbeingScreenState();
}

class _WellbeingScreenState extends ConsumerState<WellbeingScreen> {
  DateTime _focusedDay = DateTime.now();
  String? _selectedMood;

  static const _moods = [
    ('😊', 'Peaceful', 'Peaceful mind, joyful heart. Take a deep breath! 🌸'),
    ('🧘', 'Calm', 'Embrace serenity and quiet moments today 🌿'),
    ('💖', 'Loved', 'You are cherished and appreciated 💕'),
    ('⚡', 'Energetic', 'Channel your positive energy into great things! ✨'),
    ('☕', 'Cozy', 'Warm drinks and soft moments for you ☕'),
    ('😌', 'Relaxed', 'Unwind and enjoy the peaceful flow of time 🍃'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final now = DateTime.now();
    final todayStr = _fmt(now);

    final actionsAsync = ref.watch(_activeActionsProvider);
    final logsAsync = ref.watch(_logsForDateProvider(todayStr));
    final countsAsync = ref.watch(_dailyLogCountsProvider);

    final inkColor = isDark ? DesignTokens.inkDark : DesignTokens.inkLight;
    final softInk = isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Feeling Better',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: inkColor,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add self-care action',
            onPressed: () => _showAddActionSheet(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          // ── Cozy Top Hero Banner Card ─────────────────────────────────────
          AppCard(
            color: DesignTokens.resolvePastelFill(
              color: DesignTokens.peach,
              isDark: isDark,
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/images/track/wellbeing.jpg',
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 72,
                      height: 72,
                      color: Colors.white,
                      child: const Icon(Icons.self_improvement, size: 36, color: DesignTokens.rose),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Self-Care ✨',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: inkColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Nurture your mind, body, and spirit today.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: softInk,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Mood Check-in Row ─────────────────────────────────────────────
          Text(
            'HOW ARE YOU FEELING TODAY?',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: softInk,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _moods.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final (emoji, label, _) = _moods[idx];
                final isSelected = _selectedMood == label;

                return ChoiceChip(
                  avatar: Text(emoji, style: const TextStyle(fontSize: 15)),
                  label: Text(label),
                  selected: isSelected,
                  selectedColor: DesignTokens.resolvePastelFill(
                    color: DesignTokens.rose,
                    isDark: isDark,
                  ),
                  backgroundColor: isDark
                      ? DesignTokens.surfaceDark
                      : Colors.white,
                  labelStyle: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? DesignTokens.rose : inkColor,
                    fontSize: 13,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? DesignTokens.rose
                        : (isDark ? DesignTokens.lineDark : DesignTokens.lineLight),
                  ),
                  onSelected: (selected) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedMood = selected ? label : null;
                    });
                  },
                );
              },
            ),
          ),

          if (_selectedMood != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: DesignTokens.resolvePastelFill(
                  color: DesignTokens.rose,
                  isDark: isDark,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.favorite, size: 16, color: DesignTokens.rose),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _moods.firstWhere((m) => m.$2 == _selectedMood).$3,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: inkColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),

          // ── Today's Self-Care Checklist ───────────────────────────────────
          actionsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (actions) {
              if (actions.isEmpty) {
                return const EmptyState(
                  icon: Icons.self_improvement,
                  message: 'No self-care goals set',
                  hint: 'Tap + to add your daily mindful actions!',
                );
              }

              return logsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (e, s) => const SizedBox.shrink(),
                data: (logs) {
                  final loggedIds = logs.map((l) => l.actionId).toSet();
                  final total = actions.length;
                  final done = actions.where((a) => loggedIds.contains(a.id)).length;
                  final progress = total > 0 ? done / total : 0.0;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row with Progress
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "TODAY'S CHECKLIST",
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: softInk,
                            ),
                          ),
                          Text(
                            '$done of $total done',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: done == total ? DesignTokens.success : DesignTokens.rose,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: isDark
                              ? DesignTokens.lineDark
                              : DesignTokens.lineLight,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progress == 1.0
                                ? DesignTokens.success
                                : DesignTokens.rose,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // List of Self-Care Actions Cards
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: actions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final action = actions[index];
                          final isLogged = loggedIds.contains(action.id);
                          final (emoji, badgeColor) = _getSelfCareMeta(action.name);
                          final bgPastel = DesignTokens.resolvePastelFill(
                            color: badgeColor,
                            isDark: isDark,
                          );

                          return AppCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                // Emoji Badge Container
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: bgPastel,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      emoji,
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Action Title
                                Expanded(
                                  child: Text(
                                    action.name,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: isLogged ? softInk : inkColor,
                                      decoration: isLogged
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                ),

                                // Custom Checkbox Button
                                InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () async {
                                    HapticFeedback.mediumImpact();
                                    final repo = ref.read(
                                      wellbeingRepositoryProvider,
                                    );
                                    if (isLogged) {
                                      await repo.unlogAction(action.id, todayStr);
                                    } else {
                                      await repo.logAction(action.id, todayStr);
                                    }
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: isLogged
                                          ? DesignTokens.success
                                          : Colors.transparent,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isLogged
                                            ? DesignTokens.success
                                            : (isDark
                                                ? DesignTokens.lineDark
                                                : DesignTokens.lineLight),
                                        width: 2,
                                      ),
                                    ),
                                    child: isLogged
                                        ? const Icon(
                                            Icons.check,
                                            size: 18,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 6),

                                // Delete Action Icon
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: isDark
                                        ? DesignTokens.inkSoftDark
                                        : DesignTokens.inkSoftLight,
                                  ),
                                  onPressed: () => _deleteAction(action),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(height: 28),

          // ── Mindful Activity Heatmap ─────────────────────────────────────
          Text(
            'ACTIVITY HEATMAP',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: softInk,
            ),
          ),
          const SizedBox(height: 10),

          countsAsync.when(
            loading: () => const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Error: $e'),
            data: (counts) {
              return AppCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TableCalendar<void>(
                      firstDay: DateTime(2025),
                      lastDay: DateTime(2030),
                      focusedDay: _focusedDay,
                      calendarFormat: CalendarFormat.month,
                      headerStyle: HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: theme.textTheme.titleMedium!.copyWith(
                          fontWeight: FontWeight.bold,
                          color: inkColor,
                        ),
                      ),
                      onPageChanged: (focusedDay) {
                        setState(() => _focusedDay = focusedDay);
                      },
                      calendarBuilders: CalendarBuilders(
                        defaultBuilder: (context, day, _) =>
                            _buildHeatCell(day, counts, isDark),
                        todayBuilder: (context, day, _) =>
                            _buildHeatCell(day, counts, isDark, isToday: true),
                        outsideBuilder: (context, day, _) =>
                            _buildHeatCell(day, counts, isDark, isOutside: true),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Legend Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildLegendItem('No activity', isDark ? DesignTokens.surfaceDark : Colors.grey[200]!),
                        const SizedBox(width: 14),
                        _buildLegendItem('1 action', DesignTokens.resolvePastelFill(color: DesignTokens.rose, isDark: isDark)),
                        const SizedBox(width: 14),
                        _buildLegendItem('2+ actions', DesignTokens.rose),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).brightness == Brightness.dark
                ? DesignTokens.inkSoftDark
                : DesignTokens.inkSoftLight,
          ),
        ),
      ],
    );
  }

  Widget _buildHeatCell(
    DateTime day,
    Map<String, int> counts,
    bool isDark, {
    bool isToday = false,
    bool isOutside = false,
  }) {
    final dateStr = _fmt(day);
    final count = counts[dateStr] ?? 0;

    Color cellColor = Colors.transparent;
    Color textColor = isDark ? DesignTokens.inkDark : DesignTokens.inkLight;

    if (isOutside) {
      textColor = isDark ? Colors.grey[700]! : Colors.grey[300]!;
    } else if (count >= 2) {
      cellColor = DesignTokens.rose;
      textColor = Colors.white;
    } else if (count == 1) {
      cellColor = DesignTokens.resolvePastelFill(
        color: DesignTokens.rose,
        isDark: isDark,
      );
      textColor = isDark ? DesignTokens.inkDark : DesignTokens.rose;
    }

    return Container(
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: cellColor,
        shape: BoxShape.circle,
        border: isToday
            ? Border.all(
                color: DesignTokens.rose,
                width: 2,
              )
            : null,
      ),
      child: Center(
        child: Text(
          '${day.day}',
          style: TextStyle(
            color: textColor,
            fontWeight: (isToday || count > 0) ? FontWeight.bold : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Future<void> _deleteAction(WellbeingAction action) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete Self-Care Goal?',
      message:
          'Remove "${action.name}"? This deletes all completed logs for this action.',
    );
    if (confirmed == true) {
      await ref.read(wellbeingRepositoryProvider).deleteAction(action.id);
    }
  }

  void _showAddActionSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _ActionAddSheet(),
    );
  }

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

// ── Action add sheet ──────────────────────────────────────────────────────────

class _ActionAddSheet extends ConsumerStatefulWidget {
  const _ActionAddSheet();

  @override
  ConsumerState<_ActionAddSheet> createState() => _ActionAddSheetState();
}

class _ActionAddSheetState extends ConsumerState<_ActionAddSheet> {
  final _formKey = GlobalKey<FormState>();
  final _ctrl = TextEditingController();

  static const _presets = [
    ('🧘', '10m Meditation'),
    ('🎧', 'Listen to Music'),
    ('💬', 'Talk to a Friend'),
    ('🌿', '15m Nature Walk'),
    ('☕', 'Herbal Tea'),
    ('📖', 'Read Chapter'),
    ('✨', 'Skincare Routine'),
    ('✍️', 'Daily Journaling'),
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final insets = MediaQuery.viewInsetsOf(context);

    final inkColor = isDark ? DesignTokens.inkDark : DesignTokens.inkLight;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + insets.bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.self_improvement, color: DesignTokens.rose),
                const SizedBox(width: 8),
                Text(
                  'Add Self-Care Action',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: inkColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Quick Preset Chips
            Text(
              'QUICK PRESETS',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presets.map((p) {
                final (emoji, title) = p;
                return ActionChip(
                  avatar: Text(emoji),
                  label: Text(title),
                  onPressed: () {
                    _ctrl.text = title;
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _ctrl,
              decoration: InputDecoration(
                labelText: 'Action Name',
                hintText: 'e.g. 10m Meditation, Herbal Tea',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
                ),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignTokens.rose,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _submit,
              child: const Text('Add Goal', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(wellbeingRepositoryProvider).createAction(_ctrl.text.trim());
    if (mounted) Navigator.of(context).pop();
  }
}
