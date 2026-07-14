import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/db/database.dart';

typedef ClockFn = DateTime Function();

class WorktimeRepository {
  WorktimeRepository(this._db, {ClockFn? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final ClockFn _clock;

  // ── WorkContext CRUD ───────────────────────────────────────────────────────

  Future<int> createContext(String name, {String? color}) => _db
      .into(_db.workContexts)
      .insert(WorkContextsCompanion.insert(name: name, color: Value(color)));

  Stream<List<WorkContext>> watchContexts() => (_db.select(
    _db.workContexts,
  )..orderBy([(c) => OrderingTerm(expression: c.name)])).watch();

  Future<List<WorkContext>> getContexts() => (_db.select(
    _db.workContexts,
  )..orderBy([(c) => OrderingTerm(expression: c.name)])).get();

  Future<bool> updateContext(WorkContext ctx) =>
      _db.update(_db.workContexts).replace(ctx);

  Future<int> deleteContext(int id) =>
      (_db.delete(_db.workContexts)..where((c) => c.id.equals(id))).go();

  Future<int> getEntryCountForContext(int contextId) async {
    final countExpr = _db.timeEntries.id.count();
    final query = _db.selectOnly(_db.timeEntries)
      ..addColumns([countExpr])
      ..where(_db.timeEntries.contextId.equals(contextId));
    final row = await query.getSingle();
    return row.read(countExpr) ?? 0;
  }

  Future<void> deleteContextAndEntries(int contextId) async {
    await _db.transaction(() async {
      await (_db.delete(_db.timeEntries)..where((e) => e.contextId.equals(contextId))).go();
      await (_db.delete(_db.workContexts)..where((c) => c.id.equals(contextId))).go();
    });
  }

  /// Seeds the three default contexts if the table is empty.
  Future<void> seedDefaultContextsIfNeeded() async {
    final existing = await _db.select(_db.workContexts).get();
    if (existing.isNotEmpty) return;
    for (final name in const ['FreshFX', 'Tutoring', 'Startup']) {
      await createContext(name);
    }
  }

  // ── TimeEntry CRUD ─────────────────────────────────────────────────────────

  Future<int> createEntry(TimeEntriesCompanion entry) =>
      _db.into(_db.timeEntries).insert(entry);

  Stream<List<TimeEntry>> watchEntriesForDate(String date) =>
      (_db.select(_db.timeEntries)..where((e) => e.date.equals(date))).watch();

  Stream<List<TimeEntry>> watchAllEntries() => (_db.select(_db.timeEntries)
        ..orderBy([(e) => OrderingTerm(expression: e.date, mode: OrderingMode.desc)]))
      .watch();

  Future<List<TimeEntry>> getEntriesForDate(String date) =>
      (_db.select(_db.timeEntries)..where((e) => e.date.equals(date))).get();

  Future<int> deleteEntry(int id) =>
      (_db.delete(_db.timeEntries)..where((e) => e.id.equals(id))).go();

  // ── Timer helper ───────────────────────────────────────────────────────────

  /// Computes elapsed minutes, then inserts a TimeEntry with exact start/end times and location.
  Future<int> stopTimer({
    required int contextId,
    required DateTime startedAt,
    required DateTime endedAt,
    String? location,
    String? note,
  }) {
    final minutes = endedAt.difference(startedAt).inMinutes.clamp(1, 1440);
    final dateStr = _fmt(startedAt);
    return createEntry(
      TimeEntriesCompanion.insert(
        contextId: contextId,
        date: dateStr,
        minutes: minutes,
        note: Value(note),
        startTime: Value(DateFormat('HH:mm').format(startedAt)),
        endTime: Value(DateFormat('HH:mm').format(endedAt)),
        location: Value(location),
      ),
    );
  }

  // ── Rollups ────────────────────────────────────────────────────────────────

  Future<int> getTotalMinutesForDate(String date) async {
    final entries = await getEntriesForDate(date);
    return entries.fold<int>(0, (s, e) => s + e.minutes);
  }

  Future<int> getTotalMinutesForWeek(DateTime weekStart) async {
    final start = _fmt(_dayOnly(weekStart));
    final end = _fmt(_dayOnly(weekStart.add(const Duration(days: 6))));
    final entries =
        await (_db.select(_db.timeEntries)..where(
              (e) =>
                  e.date.isBiggerOrEqualValue(start) &
                  e.date.isSmallerOrEqualValue(end),
            ))
            .get();
    return entries.fold<int>(0, (s, e) => s + e.minutes);
  }

  /// Returns contextId → total minutes for the given month.
  Future<Map<int, int>> getMinutesPerContextForMonth(
    int year,
    int month,
  ) async {
    final prefix =
        '${year.toString().padLeft(4, '0')}-'
        '${month.toString().padLeft(2, '0')}-';
    final entries = await (_db.select(
      _db.timeEntries,
    )..where((e) => e.date.like('$prefix%'))).get();
    final result = <int, int>{};
    for (final e in entries) {
      result[e.contextId] = (result[e.contextId] ?? 0) + e.minutes;
    }
    return result;
  }

  // ── Settings (baseline hours/week) ────────────────────────────────────────

  static const _baselineKey = 'worktime_baseline_hours_week';

  Future<int> getBaselineHoursPerWeek() async {
    final row = await (_db.select(
      _db.appSettings,
    )..where((s) => s.key.equals(_baselineKey))).getSingleOrNull();
    return int.tryParse(row?.value ?? '') ?? 40;
  }

  Future<void> setBaselineHoursPerWeek(int hours) => _db
      .into(_db.appSettings)
      .insertOnConflictUpdate(
        AppSettingsCompanion.insert(key: _baselineKey, value: hours.toString()),
      );

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}

final worktimeRepositoryProvider = Provider<WorktimeRepository>(
  (ref) => WorktimeRepository(ref.watch(appDatabaseProvider)),
);

final workContextsProvider = StreamProvider.autoDispose<List<WorkContext>>((ref) {
  return ref.watch(worktimeRepositoryProvider).watchContexts();
});

final workEntriesProvider = StreamProvider.autoDispose<List<TimeEntry>>((ref) {
  return ref.watch(worktimeRepositoryProvider).watchAllEntries();
});
