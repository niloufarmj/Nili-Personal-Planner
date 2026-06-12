import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/db/database.dart';
import '../../core/design/design.dart';
import 'repositories/worktime_repository.dart';
import 'services/rollup_service.dart';

final _workContextsProvider = StreamProvider.autoDispose((ref) {
  return ref.watch(worktimeRepositoryProvider).watchContexts();
});

final _workEntriesForDateProvider = StreamProvider.autoDispose.family<List<TimeEntry>, String>((ref, dateStr) {
  return ref.watch(worktimeRepositoryProvider).watchEntriesForDate(dateStr);
});

// ── Timer state (persisted via SharedPreferences) ────────────────────────────

const _timerContextKey = 'worktime_timer_context_id';
const _timerStartKey = 'worktime_timer_started_at';

class WorktimeScreen extends ConsumerStatefulWidget {
  const WorktimeScreen({super.key});

  @override
  ConsumerState<WorktimeScreen> createState() => _WorktimeScreenState();
}

class _WorktimeScreenState extends ConsumerState<WorktimeScreen> {
  int? _timerContextId;
  DateTime? _timerStartedAt;

  @override
  void initState() {
    super.initState();
    _loadTimerState();
    _seedContexts();
  }

  Future<void> _seedContexts() =>
      ref.read(worktimeRepositoryProvider).seedDefaultContextsIfNeeded();

  Future<void> _loadTimerState() async {
    final prefs = await SharedPreferences.getInstance();
    final ctxId = prefs.getInt(_timerContextKey);
    final startMs = prefs.getInt(_timerStartKey);
    if (ctxId != null && startMs != null) {
      setState(() {
        _timerContextId = ctxId;
        _timerStartedAt = DateTime.fromMillisecondsSinceEpoch(startMs);
      });
    }
  }

  Future<void> _startTimer(int contextId) async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_timerContextKey, contextId);
    await prefs.setInt(_timerStartKey, now.millisecondsSinceEpoch);
    setState(() {
      _timerContextId = contextId;
      _timerStartedAt = now;
    });
  }

  Future<void> _stopTimer() async {
    if (_timerContextId == null || _timerStartedAt == null) return;
    await ref
        .read(worktimeRepositoryProvider)
        .stopTimer(contextId: _timerContextId!, startedAt: _timerStartedAt!);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_timerContextKey);
    await prefs.remove(_timerStartKey);
    setState(() {
      _timerContextId = null;
      _timerStartedAt = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Work Time')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'worktime_fab',
        child: const Icon(Icons.add),
        onPressed: () => _showQuickAdd(context),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _TimerCard(
            timerContextId: _timerContextId,
            timerStartedAt: _timerStartedAt,
            onStart: _startTimer,
            onStop: _stopTimer,
          ),
          const SizedBox(height: 16),
          const _RollupCard(),
          const SizedBox(height: 16),
          const SectionHeader(title: "Today's Log"),
          const SizedBox(height: 8),
          _TodayLog(date: _todayStr()),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Future<void> _showQuickAdd(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _QuickAddSheet(),
    );
  }

  static String _todayStr() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}

// ── Timer card ────────────────────────────────────────────────────────────────

class _TimerCard extends ConsumerWidget {
  const _TimerCard({
    required this.timerContextId,
    required this.timerStartedAt,
    required this.onStart,
    required this.onStop,
  });

  final int? timerContextId;
  final DateTime? timerStartedAt;
  final Future<void> Function(int contextId) onStart;
  final Future<void> Function() onStop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctxAsync = ref.watch(_workContextsProvider);

    final isRunning = timerContextId != null;

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timer_outlined),
                const SizedBox(width: 8),
                Text(
                  isRunning ? 'Timer running' : 'Timer',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (isRunning && timerStartedAt != null) ...[
                  const Spacer(),
                  Text(
                    'since ${DateFormat('HH:mm').format(timerStartedAt!)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            if (isRunning)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                  onPressed: onStop,
                ),
              )
            else
              ctxAsync.when(
                loading: () => const LinearProgressIndicator(minHeight: 2),
                error: (e, _) => Text('$e'),
                data: (contexts) {
                  if (contexts.isEmpty) {
                    return const Text('No contexts yet');
                  }
                  return Wrap(
                    spacing: 8,
                    children: contexts
                        .map(
                          (ctx) => ActionChip(
                            label: Text(ctx.name),
                            avatar: const Icon(Icons.play_arrow, size: 16),
                            onPressed: () => onStart(ctx.id),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ── Rollup card ───────────────────────────────────────────────────────────────

class _RollupCard extends ConsumerWidget {
  const _RollupCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(worktimeRepositoryProvider);
    final now = DateTime.now();
    final todayStr = _fmt(now);
    final weekStart = now.subtract(Duration(days: now.weekday - 1));

    return FutureBuilder<RollupResult>(
      future: _loadRollup(repo, todayStr, weekStart, now),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const AppCard(child: LinearProgressIndicator(minHeight: 2));
        }
        final r = snap.data!;
        final savedColor = r.savedDays >= 0
            ? Colors.green[700]
            : Colors.orange[700];

        return AppCard(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rollup', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                _StatRow(
                  label: 'Today',
                  value: RollupService.formatMinutes(r.todayMinutes),
                ),
                _StatRow(
                  label: 'This week',
                  value: RollupService.formatMinutes(r.weekMinutes),
                ),
                _StatRow(
                  label: 'Baseline',
                  value: '${r.baselineHoursPerWeek}h/week',
                ),
                const Divider(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      r.savedDays >= 0 ? 'Saved days' : 'Deficit days',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      r.savedDays.abs().toStringAsFixed(1),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: savedColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<RollupResult> _loadRollup(
    WorktimeRepository repo,
    String todayStr,
    DateTime weekStart,
    DateTime now,
  ) async {
    final todayMin = await repo.getTotalMinutesForDate(todayStr);
    final weekMin = await repo.getTotalMinutesForWeek(weekStart);
    final monthCtx = await repo.getMinutesPerContextForMonth(
      now.year,
      now.month,
    );
    final baseline = await repo.getBaselineHoursPerWeek();
    return RollupService.compute(
      todayMinutes: todayMin,
      weekMinutes: weekMin,
      monthPerContext: monthCtx,
      baselineHoursPerWeek: baseline,
    );
  }

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

// ── Today log ─────────────────────────────────────────────────────────────────

class _TodayLog extends ConsumerWidget {
  const _TodayLog({required this.date});
  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(_workEntriesForDateProvider(date));

    return entriesAsync.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (e, _) => Text('$e'),
      data: (entries) {
        if (entries.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Text(
              'No entries today',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }
        return Column(
          children: entries
              .map(
                (e) => AppCard(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    leading: const Icon(Icons.access_time),
                    title: Text(e.note ?? 'Work session'),
                    subtitle: Text('Context #${e.contextId}'),
                    trailing: Text(
                      RollupService.formatMinutes(e.minutes),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onLongPress: () async {
                      final confirmed = await ConfirmDialog.show(
                        context,
                        title: 'Delete entry?',
                        message: 'Remove this time entry?',
                      );
                      if (confirmed == true) {
                        await ref
                            .read(worktimeRepositoryProvider)
                            .deleteEntry(e.id);
                      }
                    },
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

// ── Quick-add sheet ───────────────────────────────────────────────────────────

class _QuickAddSheet extends ConsumerStatefulWidget {
  const _QuickAddSheet();

  @override
  ConsumerState<_QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<_QuickAddSheet> {
  final _formKey = GlobalKey<FormState>();
  final _minutesCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  int? _contextId;

  @override
  void dispose() {
    _minutesCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context);
    final ctxAsync = ref.watch(_workContextsProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + insets.bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Log Time', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ctxAsync.when(
              loading: () => const LinearProgressIndicator(minHeight: 2),
              error: (e, _) => Text('$e'),
              data: (contexts) => DropdownButtonFormField<int>(
                hint: const Text('Context'),
                items: contexts
                    .map(
                      (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _contextId = v),
                decoration: const InputDecoration(
                  labelText: 'Work Context',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null ? 'Required' : null,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _minutesCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Minutes',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n <= 0) return 'Enter positive minutes';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: _submit, child: const Text('Log')),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final now = DateTime.now();
    final dateStr =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    await ref
        .read(worktimeRepositoryProvider)
        .createEntry(
          TimeEntriesCompanion.insert(
            contextId: _contextId!,
            date: dateStr,
            minutes: int.parse(_minutesCtrl.text),
            note: Value(
              _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
            ),
          ),
        );
    if (mounted) Navigator.of(context).pop();
  }
}
