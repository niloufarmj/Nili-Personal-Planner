import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';

class WellbeingRepository {
  const WellbeingRepository(this._db);

  final AppDatabase _db;

  // ── Actions CRUD ───────────────────────────────────────────────────────────

  Stream<List<WellbeingAction>> watchActiveActions() {
    return (_db.select(_db.wellbeingActions)..where((a) => a.active.equals(true))).watch();
  }

  Future<List<WellbeingAction>> getActiveActions() {
    return (_db.select(_db.wellbeingActions)..where((a) => a.active.equals(true))).get();
  }

  Future<int> createAction(String name) async {
    return _db.into(_db.wellbeingActions).insert(
          WellbeingActionsCompanion.insert(name: name),
        );
  }

  Future<int> deleteAction(int id) {
    return (_db.delete(_db.wellbeingActions)..where((a) => a.id.equals(id))).go();
  }

  // ── Logging ────────────────────────────────────────────────────────────────

  Stream<List<WellbeingLog>> watchLogsForDate(String dateIso) {
    return (_db.select(_db.wellbeingLogs)..where((l) => l.date.equals(dateIso))).watch();
  }

  Future<void> logAction(int actionId, String dateIso) async {
    await _db.into(_db.wellbeingLogs).insertOnConflictUpdate(
          WellbeingLogsCompanion.insert(
            date: dateIso,
            actionId: actionId,
          ),
        );
  }

  Future<void> unlogAction(int actionId, String dateIso) async {
    await (_db.delete(_db.wellbeingLogs)
          ..where((l) => l.actionId.equals(actionId) & l.date.equals(dateIso)))
        .go();
  }

  // ── Heat Map / Calendar counts ──────────────────────────────────────────────

  /// Stream of all logs grouped by date to count actions logged per day.
  Stream<Map<String, int>> watchDailyLogCounts() {
    return _db.select(_db.wellbeingLogs).watch().map((logs) {
      final counts = <String, int>{};
      for (final log in logs) {
        counts[log.date] = (counts[log.date] ?? 0) + 1;
      }
      return counts;
    });
  }

  // ── Seeding ────────────────────────────────────────────────────────────────

  Future<void> seedDefaultActionsIfNeeded() async {
    final existing = await _db.select(_db.wellbeingActions).get();
    if (existing.isNotEmpty) return;

    final defaults = ['meditation', 'talk to a friend', 'listen to music'];
    for (final name in defaults) {
      await _db.into(_db.wellbeingActions).insert(
            WellbeingActionsCompanion.insert(name: name),
          );
    }
  }
}

final wellbeingRepositoryProvider = Provider<WellbeingRepository>(
  (ref) => WellbeingRepository(ref.watch(appDatabaseProvider)),
);
