import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';

class TransactionRepository {
  const TransactionRepository(this._db);

  final AppDatabase _db;

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<int> create(TransactionsCompanion companion) =>
      _db.into(_db.transactions).insert(companion);

  Future<bool> update(Transaction tx) =>
      _db.update(_db.transactions).replace(tx);

  Future<int> delete(int id) =>
      (_db.delete(_db.transactions)..where((t) => t.id.equals(id))).go();

  Future<Transaction?> getById(int id) => (_db.select(
    _db.transactions,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  // ── Queries ───────────────────────────────────────────────────────────────

  Stream<List<Transaction>> watchByMonth(int year, int month) {
    final prefix = _monthPrefix(year, month);
    return (_db.select(_db.transactions)
          ..where((t) => t.date.like('$prefix%'))
          ..orderBy([
            (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Future<List<Transaction>> getByMonth(int year, int month) {
    final prefix = _monthPrefix(year, month);
    return (_db.select(_db.transactions)
          ..where((t) => t.date.like('$prefix%'))
          ..orderBy([
            (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
          ]))
        .get();
  }

  Stream<List<Transaction>> watchByMonthFiltered(
    int year,
    int month, {
    String? category,
    String? direction,
    String? status,
  }) {
    final prefix = _monthPrefix(year, month);
    return (_db.select(_db.transactions)
          ..where((t) {
            Expression<bool> expr = t.date.like('$prefix%');
            if (category != null) expr = expr & t.category.equals(category);
            if (direction != null) expr = expr & t.direction.equals(direction);
            if (status != null) expr = expr & t.status.equals(status);
            return expr;
          })
          ..orderBy([(t) => OrderingTerm(expression: t.date)]))
        .watch();
  }

  Future<List<Transaction>> getByDate(String date) =>
      (_db.select(_db.transactions)..where((t) => t.date.equals(date))).get();

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _monthPrefix(int year, int month) =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-';
}

final transactionRepositoryProvider = Provider<TransactionRepository>(
  (ref) => TransactionRepository(ref.watch(appDatabaseProvider)),
);
