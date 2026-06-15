import 'package:drift/drift.dart' show OrderingMode, OrderingTerm, Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../db/database.dart';

/// Links shopping-list items to finance transactions.
///
/// Contract (docs/contracts.md §13):
/// - [createFromItem] writes a planned transaction and stores [itemId].
/// - [markBought] converts that transaction to actual with the real cost.
/// - Both calls are idempotent: calling twice for the same item has no effect.
class ExpenseLinkService {
  const ExpenseLinkService(this._db);

  final AppDatabase _db;

  /// Creates a planned 'out' transaction for the given shopping item.
  /// Returns the new transaction id, or the existing id if already created.
  Future<int> createFromItem({
    required int itemId,
    required String title,
    required int plannedCostCents,
  }) async {
    final existing = await _findByItemId(itemId);
    if (existing != null) return existing.id;

    return _db
        .into(_db.transactions)
        .insert(
          TransactionsCompanion.insert(
            date: _todayStr(),
            amountCents: plannedCostCents,
            direction: 'out',
            status: 'planned',
            category: 'shopping',
            note: Value(title),
            itemId: Value(itemId),
          ),
        );
  }

  /// Converts the planned transaction for [itemId] to actual with [actualCostCents].
  /// If no linked transaction exists, creates an actual one directly.
  Future<void> markBought({
    required int itemId,
    required String title,
    required int actualCostCents,
  }) async {
    final existing = await _findByItemId(itemId);
    if (existing != null) {
      await _db
          .update(_db.transactions)
          .replace(
            existing.copyWith(
              status: 'actual',
              amountCents: actualCostCents,
              date: _todayStr(),
            ),
          );
    } else {
      await _db
          .into(_db.transactions)
          .insert(
            TransactionsCompanion.insert(
              date: _todayStr(),
              amountCents: actualCostCents,
              direction: 'out',
              status: 'actual',
              category: 'shopping',
              note: Value(title),
              itemId: Value(itemId),
            ),
          );
    }
  }

  Future<Transaction?> _findByItemId(int itemId) =>
      (_db.select(_db.transactions)
            ..where((t) => t.itemId.equals(itemId))
            ..orderBy([
              (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
            ])
            ..limit(1))
          .getSingleOrNull();

  static String _todayStr() {
    final now = DateTime.now();
    return DateFormat('yyyy-MM-dd').format(now);
  }
}

final expenseLinkServiceProvider = Provider<ExpenseLinkService>(
  (ref) => ExpenseLinkService(ref.watch(appDatabaseProvider)),
);
