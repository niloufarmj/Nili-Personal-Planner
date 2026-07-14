import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/db/database.dart';

class PeriodRepository {
  const PeriodRepository(this._db);

  final AppDatabase _db;

  // ── Database Queries ───────────────────────────────────────────────────────

  Stream<List<PeriodLog>> watchLogs() {
    return (_db.select(_db.periodLogs)
          ..orderBy([
            (t) => OrderingTerm(expression: t.startDate, mode: OrderingMode.asc)
          ]))
        .watch();
  }

  Future<List<PeriodLog>> getLogs() {
    return (_db.select(_db.periodLogs)
          ..orderBy([
            (t) => OrderingTerm(expression: t.startDate, mode: OrderingMode.asc)
          ]))
        .get();
  }

  Future<int> addLog(DateTime startDate, int durationDays) async {
    final dateIso = _fmtDate(startDate);
    return _db.into(_db.periodLogs).insertOnConflictUpdate(
          PeriodLogsCompanion.insert(
            startDate: dateIso,
            durationDays: Value(durationDays),
          ),
        );
  }

  Future<void> updateLog(int id, DateTime startDate, int durationDays) async {
    final dateIso = _fmtDate(startDate);
    await (_db.update(_db.periodLogs)..where((t) => t.id.equals(id))).write(
      PeriodLogsCompanion(
        startDate: Value(dateIso),
        durationDays: Value(durationDays),
      ),
    );
  }

  Future<int> deleteLog(int id) {
    return (_db.delete(_db.periodLogs)..where((t) => t.id.equals(id))).go();
  }

  // ── Settings ───────────────────────────────────────────────────────────────

  static const _cycleLengthKey = 'period_default_cycle_length';
  static const _durationKey = 'period_default_duration';
  static const _remindersEnabledKey = 'period_reminders_enabled';
  static const _lastAskDateKey = 'period_last_ask_date';
  static const _lastNoDateKey = 'period_last_no_date';

  Future<int> getDefaultCycleLength() async {
    final row = await (_db.select(_db.appSettings)
          ..where((s) => s.key.equals(_cycleLengthKey)))
        .getSingleOrNull();
    return int.tryParse(row?.value ?? '') ?? 28;
  }

  Future<void> setDefaultCycleLength(int days) async {
    await _db.into(_db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: _cycleLengthKey,
            value: days.toString(),
          ),
        );
  }

  Future<int> getDefaultDuration() async {
    final row = await (_db.select(_db.appSettings)
          ..where((s) => s.key.equals(_durationKey)))
        .getSingleOrNull();
    return int.tryParse(row?.value ?? '') ?? 5;
  }

  Future<void> setDefaultDuration(int days) async {
    await _db.into(_db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: _durationKey,
            value: days.toString(),
          ),
        );
  }

  Future<bool> getRemindersEnabled() async {
    final row = await (_db.select(_db.appSettings)
          ..where((s) => s.key.equals(_remindersEnabledKey)))
        .getSingleOrNull();
    return row?.value != 'false';
  }

  Future<void> setRemindersEnabled(bool enabled) async {
    await _db.into(_db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: _remindersEnabledKey,
            value: enabled.toString(),
          ),
        );
  }

  Future<String?> getLastAskDate() async {
    final row = await (_db.select(_db.appSettings)
          ..where((s) => s.key.equals(_lastAskDateKey)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setLastAskDate(String dateStr) async {
    await _db.into(_db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion.insert(key: _lastAskDateKey, value: dateStr),
        );
  }

  Future<String?> getLastNoDate() async {
    final row = await (_db.select(_db.appSettings)
          ..where((s) => s.key.equals(_lastNoDateKey)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setLastNoDate(String dateStr) async {
    await _db.into(_db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion.insert(key: _lastNoDateKey, value: dateStr),
        );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

final periodRepositoryProvider = Provider<PeriodRepository>(
  (ref) => PeriodRepository(ref.watch(appDatabaseProvider)),
);
