import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_planner/core/db/database.dart';
import 'package:personal_planner/core/services/expense_link_service.dart';

AppDatabase _openDb() => AppDatabase(NativeDatabase.memory());

void main() {
  late AppDatabase db;
  late ExpenseLinkService service;

  setUp(() {
    db = _openDb();
    service = ExpenseLinkService(db);
  });

  tearDown(() => db.close());

  test('createFromItem writes a planned transaction', () async {
    final txId = await service.createFromItem(
      itemId: 42,
      title: 'Running shoes',
      plannedCostCents: 8999,
    );

    final txs = await db.select(db.transactions).get();
    expect(txs.length, 1);
    final tx = txs.first;
    expect(tx.id, txId);
    expect(tx.status, 'planned');
    expect(tx.direction, 'out');
    expect(tx.category, 'shopping');
    expect(tx.amountCents, 8999);
    expect(tx.itemId, 42);
    expect(tx.note, 'Running shoes');
  });

  test(
    'createFromItem is idempotent — no duplicate transaction per item',
    () async {
      final id1 = await service.createFromItem(
        itemId: 7,
        title: 'Bike helmet',
        plannedCostCents: 4500,
      );
      final id2 = await service.createFromItem(
        itemId: 7,
        title: 'Bike helmet',
        plannedCostCents: 4500,
      );

      expect(id1, id2);
      final txs = await db.select(db.transactions).get();
      expect(txs.length, 1);
    },
  );

  test('markBought converts planned to actual with new cost', () async {
    await service.createFromItem(
      itemId: 10,
      title: 'Headphones',
      plannedCostCents: 20000,
    );

    await service.markBought(
      itemId: 10,
      title: 'Headphones',
      actualCostCents: 18500,
    );

    final txs = await db.select(db.transactions).get();
    expect(txs.length, 1);
    expect(txs.first.status, 'actual');
    expect(txs.first.amountCents, 18500);
  });

  test(
    'markBought without prior createFromItem creates actual transaction',
    () async {
      await service.markBought(
        itemId: 99,
        title: 'Mystery item',
        actualCostCents: 1000,
      );

      final txs = await db.select(db.transactions).get();
      expect(txs.length, 1);
      expect(txs.first.status, 'actual');
      expect(txs.first.itemId, 99);
    },
  );

  test('markBought is idempotent when called twice', () async {
    await service.createFromItem(
      itemId: 5,
      title: 'Book',
      plannedCostCents: 1500,
    );
    await service.markBought(itemId: 5, title: 'Book', actualCostCents: 1400);
    await service.markBought(itemId: 5, title: 'Book', actualCostCents: 1400);

    final txs = await db.select(db.transactions).get();
    expect(txs.length, 1);
    expect(txs.first.status, 'actual');
  });
}
