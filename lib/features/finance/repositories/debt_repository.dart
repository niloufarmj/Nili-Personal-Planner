import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';

class DebtRepository {
  const DebtRepository(this._db);

  final AppDatabase _db;

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<int> create(DebtsCompanion companion) =>
      _db.into(_db.debts).insert(companion);

  Future<bool> update(Debt debt) => _db.update(_db.debts).replace(debt);

  Future<int> delete(int id) =>
      (_db.delete(_db.debts)..where((d) => d.id.equals(id))).go();

  Stream<List<Debt>> watchAll() =>
      (_db.select(_db.debts)
            ..where((d) => d.settled.equals(false))
            ..orderBy([(d) => OrderingTerm(expression: d.person)]))
          .watch();

  Stream<List<Debt>> watchSettled() =>
      (_db.select(_db.debts)
            ..where((d) => d.settled.equals(true))
            ..orderBy([(d) => OrderingTerm(expression: d.person)]))
          .watch();

  Future<void> settle(int id) =>
      (_db.update(_db.debts)..where((d) => d.id.equals(id))).write(
        const DebtsCompanion(settled: Value(true)),
      );

  Future<void> reopen(int id) =>
      (_db.update(_db.debts)..where((d) => d.id.equals(id))).write(
        const DebtsCompanion(settled: Value(false)),
      );
}

final debtRepositoryProvider = Provider<DebtRepository>(
  (ref) => DebtRepository(ref.watch(appDatabaseProvider)),
);
