import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../models/projected_entry.dart';

class RecurringRepository {
  const RecurringRepository(this._db);

  final AppDatabase _db;

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<int> create(RecurringTransactionsCompanion companion) =>
      _db.into(_db.recurringTransactions).insert(companion);

  Future<bool> update(RecurringTransaction rt) =>
      _db.update(_db.recurringTransactions).replace(rt);

  Future<int> delete(int id) => (_db.delete(
    _db.recurringTransactions,
  )..where((r) => r.id.equals(id))).go();

  Future<void> setActive(int id, {required bool active}) =>
      (_db.update(_db.recurringTransactions)..where((r) => r.id.equals(id)))
          .write(RecurringTransactionsCompanion(active: Value(active)));

  Stream<List<RecurringTransaction>> watchAll() => (_db.select(
    _db.recurringTransactions,
  )..orderBy([(r) => OrderingTerm(expression: r.name)])).watch();

  Future<List<RecurringTransaction>> getAll() =>
      _db.select(_db.recurringTransactions).get();

  // ── Projection ────────────────────────────────────────────────────────────

  /// Returns synthetic entries for all active recurring transactions
  /// applicable in [month]. Entries after the month's end are excluded;
  /// entries before today are still included (ForecastService filters them).
  Future<List<ProjectedEntry>> expandForMonth(DateTime month) async {
    final monthStr = _monthStr(month);

    final rows =
        await (_db.select(_db.recurringTransactions)..where(
              (r) =>
                  r.active.equals(true) &
                  r.startMonth.isSmallerOrEqualValue(monthStr) &
                  (r.endMonth.isNull() |
                      r.endMonth.isBiggerOrEqualValue(monthStr)),
            ))
            .get();

    final lastDay = _lastDayOfMonth(month.year, month.month);

    return rows.map((r) {
      final day = r.dayOfMonth.clamp(1, lastDay);
      final dateStr = '$monthStr-${day.toString().padLeft(2, '0')}';
      return ProjectedEntry(
        amountCents: r.amountCents,
        direction: r.direction,
        category: r.category,
        date: dateStr,
        name: r.name,
        recurringId: r.id,
      );
    }).toList();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _monthStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}';

  static int _lastDayOfMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;
}

final recurringRepositoryProvider = Provider<RecurringRepository>(
  (ref) => RecurringRepository(ref.watch(appDatabaseProvider)),
);
