import 'dart:async';
import 'dart:ui'; // for FontFeature
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Work Time',
          style: GoogleFonts.fraunces(
            fontSize: DesignTokens.fontTitle,
            fontWeight: FontWeight.w600,
            color: isDark ? DesignTokens.inkDark : DesignTokens.inkLight,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'worktime_fab',
        backgroundColor: isDark ? DesignTokens.accentDark : DesignTokens.accentLight,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
        onPressed: () => _showQuickAdd(context),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        children: [
          _TimerCard(
            timerContextId: _timerContextId,
            timerStartedAt: _timerStartedAt,
            onStart: _startTimer,
            onStop: _stopTimer,
          ),
          const SizedBox(height: 20),
          const _RollupCard(),
          const SizedBox(height: 24),
          const SectionHeader(title: "Today's Log"),
          const SizedBox(height: 8),
          _TodayLog(date: _todayStr()),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Future<void> _showQuickAdd(BuildContext context) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? DesignTokens.paperDark : DesignTokens.paperLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(DesignTokens.radiusSheet)),
      ),
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

class _TimerCard extends ConsumerStatefulWidget {
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
  ConsumerState<_TimerCard> createState() => _TimerCardState();
}

class _TimerCardState extends ConsumerState<_TimerCard> {
  int? _selectedContextId;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.timerStartedAt != null) {
      _startTicker();
    }
  }

  @override
  void didUpdateWidget(covariant _TimerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.timerStartedAt != oldWidget.timerStartedAt) {
      if (widget.timerStartedAt != null) {
        _startTicker();
      } else {
        _ticker?.cancel();
        setState(() {
          _elapsed = Duration.zero;
        });
      }
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    _updateElapsed();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateElapsed();
    });
  }

  void _updateElapsed() {
    if (widget.timerStartedAt == null) return;
    setState(() {
      _elapsed = DateTime.now().difference(widget.timerStartedAt!);
    });
  }

  String _formatDuration(Duration d) {
    final hh = d.inHours.toString().padLeft(2, '0');
    final mm = (d.inMinutes % 60).toString().padLeft(2, '0');
    final ss = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final ctxAsync = ref.watch(_workContextsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isRunning = widget.timerContextId != null;

    final inkColor = isDark ? DesignTokens.inkDark : DesignTokens.inkLight;

    Widget cardContent = Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.timer_outlined,
                color: isRunning 
                    ? (isDark ? DesignTokens.accentDark : DesignTokens.accentLight) 
                    : (isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight),
              ),
              const SizedBox(width: 8),
              Text(
                isRunning ? 'Timer Running' : 'Timer',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: inkColor,
                ),
              ),
              if (isRunning && widget.timerStartedAt != null) ...[
                const Spacer(),
                Text(
                  'since ${DateFormat('HH:mm').format(widget.timerStartedAt!)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          if (isRunning)
            Column(
              children: [
                Center(
                  child: Text(
                    _formatDuration(_elapsed),
                    style: GoogleFonts.fraunces(
                      fontSize: 48,
                      fontWeight: FontWeight.w600,
                      color: inkColor,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop Timer'),
                    style: FilledButton.styleFrom(
                      backgroundColor: isDark ? DesignTokens.danger.withValues(alpha: 0.9) : DesignTokens.danger,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
                      ),
                    ),
                    onPressed: widget.onStop,
                  ),
                ),
              ],
            )
          else
            ctxAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: ShimmerSkeleton(width: double.infinity, height: 80),
              ),
              error: (e, _) => Text('$e'),
              data: (contexts) {
                if (contexts.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No contexts yet. Create one via + FAB.'),
                  );
                }
                
                _selectedContextId ??= contexts.first.id;

                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: isDark ? DesignTokens.lineDark : DesignTokens.lineLight),
                        borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
                        color: isDark ? DesignTokens.surfaceDark : Colors.white,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _selectedContextId,
                          isExpanded: true,
                          dropdownColor: isDark ? DesignTokens.surfaceDark : Colors.white,
                          style: theme.textTheme.bodyMedium?.copyWith(color: inkColor),
                          items: contexts.map((c) {
                            return DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedContextId = val;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start Timer'),
                        style: FilledButton.styleFrom(
                          backgroundColor: isDark ? DesignTokens.accentDark : DesignTokens.accentLight,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
                          ),
                        ),
                        onPressed: () => widget.onStart(_selectedContextId!),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );

    // Apply sweep shimmer border animation if running
    if (isRunning) {
      cardContent = cardContent.animate(
        onPlay: (controller) => controller.repeat(),
      ).shimmer(
        duration: 2.seconds,
        color: (isDark ? DesignTokens.accentDark : DesignTokens.accentLight).withValues(alpha: 0.15),
      );
    }

    return AppCard(child: cardContent);
  }
}

// ── Rollup card ───────────────────────────────────────────────────────────────

class _RollupCard extends ConsumerWidget {
  const _RollupCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(worktimeRepositoryProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final now = DateTime.now();
    final todayStr = _fmt(now);
    final weekStart = now.subtract(Duration(days: now.weekday - 1));

    final inkColor = isDark ? DesignTokens.inkDark : DesignTokens.inkLight;

    return FutureBuilder<RollupResult>(
      future: _loadRollup(repo, todayStr, weekStart, now),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const AppCard(
            child: SizedBox(
              height: 140,
              child: Center(
                child: ShimmerSkeleton(width: double.infinity, height: 120),
              ),
            ),
          );
        }
        
        final r = snap.data!;
        final savedColor = r.savedDays >= 0
            ? DesignTokens.success
            : DesignTokens.warning;

        return AppCard(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rollup',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: inkColor,
                  ),
                ),
                const SizedBox(height: 12),
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
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        if (r.savedDays > 0) ...[
                          Icon(Icons.flight, size: 14, color: savedColor),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          r.savedDays >= 0 ? 'Saved days' : 'Deficit days',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      r.savedDays.abs().toStringAsFixed(1),
                      style: theme.textTheme.bodyMedium?.copyWith(
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? DesignTokens.inkDark : DesignTokens.inkLight,
            ),
          ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final inkColor = isDark ? DesignTokens.inkDark : DesignTokens.inkLight;

    return entriesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: ShimmerSkeleton(width: double.infinity, height: 80),
      ),
      error: (e, _) => Text('$e'),
      data: (entries) {
        if (entries.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(left: 4, top: 4),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDark ? DesignTokens.surfaceDark : DesignTokens.resolvePastelFill(color: DesignTokens.lavender, isDark: false),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.access_time,
                        color: isDark ? DesignTokens.inkDark : DesignTokens.lavender,
                        size: 18,
                      ),
                    ),
                    title: Text(
                      e.note ?? 'Work session',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: inkColor,
                      ),
                    ),
                    subtitle: Text(
                      'Session #${e.id}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
                      ),
                    ),
                    trailing: Text(
                      RollupService.formatMinutes(e.minutes),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: inkColor,
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + insets.bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Log Time',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontFamily: GoogleFonts.fraunces().fontFamily,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ctxAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: ShimmerSkeleton(width: double.infinity, height: 48),
              ),
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
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: isDark ? DesignTokens.accentDark : DesignTokens.accentLight,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
                ),
              ),
              onPressed: _submit,
              child: const Text('Log'),
            ),
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
