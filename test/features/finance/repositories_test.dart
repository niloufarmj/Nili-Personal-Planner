import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_planner/core/db/database.dart';
import 'package:personal_planner/features/finance/repositories/debt_repository.dart';
import 'package:personal_planner/features/finance/repositories/recurring_repository.dart';
import 'package:personal_planner/features/finance/repositories/transaction_repository.dart';

AppDatabase _openDb() => AppDatabase(NativeDatabase.memory());

void main() {
  late AppDatabase db;
  late TransactionRepository txRepo;
  late RecurringRepository recRepo;
  late DebtRepository debtRepo;

  setUp(() {
    db = _openDb();
    txRepo = TransactionRepository(db);
    recRepo = RecurringRepository(db);
    debtRepo = DebtRepository(db);
  });

  tearDown(() => db.close());

  // ── TransactionRepository ─────────────────────────────────────────────────

  group('TransactionRepository', () {
    test('CRUD', () async {
      final id = await txRepo.create(
        TransactionsCompanion.insert(
          date: '2026-06-10',
          amountCents: 500,
          direction: 'out',
          status: 'actual',
          category: 'food',
        ),
      );
      final tx = await txRepo.getById(id);
      expect(tx, isNotNull);
      expect(tx!.amountCents, 500);

      await txRepo.update(tx.copyWith(amountCents: 600));
      final updated = await txRepo.getById(id);
      expect(updated!.amountCents, 600);

      await txRepo.delete(id);
      expect(await txRepo.getById(id), isNull);
    });

    test('getByMonth returns only that month', () async {
      await txRepo.create(
        TransactionsCompanion.insert(
          date: '2026-06-01',
          amountCents: 100,
          direction: 'out',
          status: 'actual',
          category: 'food',
        ),
      );
      await txRepo.create(
        TransactionsCompanion.insert(
          date: '2026-07-01',
          amountCents: 200,
          direction: 'out',
          status: 'actual',
          category: 'food',
        ),
      );

      final june = await txRepo.getByMonth(2026, 6);
      expect(june.length, 1);
      expect(june.first.amountCents, 100);
    });

    test('getByDate returns only that date', () async {
      await txRepo.create(
        TransactionsCompanion.insert(
          date: '2026-06-15',
          amountCents: 300,
          direction: 'out',
          status: 'planned',
          category: 'shopping',
        ),
      );
      await txRepo.create(
        TransactionsCompanion.insert(
          date: '2026-06-16',
          amountCents: 400,
          direction: 'out',
          status: 'planned',
          category: 'shopping',
        ),
      );

      final txs = await txRepo.getByDate('2026-06-15');
      expect(txs.length, 1);
      expect(txs.first.amountCents, 300);
    });
  });

  // ── RecurringRepository ───────────────────────────────────────────────────

  group('RecurringRepository', () {
    test('CRUD and active toggle', () async {
      final id = await recRepo.create(
        RecurringTransactionsCompanion.insert(
          name: 'Netflix',
          amountCents: 1499,
          direction: 'out',
          dayOfMonth: 15,
          startMonth: '2026-01',
          category: 'subscription',
        ),
      );

      final all = await recRepo.getAll();
      expect(all.length, 1);
      expect(all.first.active, true);

      await recRepo.setActive(id, active: false);
      final updated = (await recRepo.getAll()).first;
      expect(updated.active, false);

      await recRepo.delete(id);
      expect(await recRepo.getAll(), isEmpty);
    });

    test('expandForMonth includes active recurring in range', () async {
      await recRepo.create(
        RecurringTransactionsCompanion.insert(
          name: 'Rent',
          amountCents: 70000,
          direction: 'out',
          dayOfMonth: 1,
          startMonth: '2026-01',
          category: 'rent',
        ),
      );

      final entries = await recRepo.expandForMonth(DateTime(2026, 6));
      expect(entries.length, 1);
      expect(entries.first.date, '2026-06-01');
      expect(entries.first.amountCents, 70000);
    });

    test('expandForMonth excludes inactive recurring', () async {
      final id = await recRepo.create(
        RecurringTransactionsCompanion.insert(
          name: 'Old sub',
          amountCents: 999,
          direction: 'out',
          dayOfMonth: 10,
          startMonth: '2026-01',
          category: 'subscription',
        ),
      );
      await recRepo.setActive(id, active: false);

      final entries = await recRepo.expandForMonth(DateTime(2026, 6));
      expect(entries, isEmpty);
    });

    test('expandForMonth respects startMonth boundary', () async {
      await recRepo.create(
        RecurringTransactionsCompanion.insert(
          name: 'New salary',
          amountCents: 200000,
          direction: 'in',
          dayOfMonth: 25,
          startMonth: '2026-07', // starts in July
          category: 'income',
        ),
      );

      final junEntries = await recRepo.expandForMonth(DateTime(2026, 6));
      expect(junEntries, isEmpty);

      final julEntries = await recRepo.expandForMonth(DateTime(2026, 7));
      expect(julEntries.length, 1);
      expect(julEntries.first.date, '2026-07-25');
    });

    test('expandForMonth respects endMonth boundary', () async {
      await recRepo.create(
        RecurringTransactionsCompanion.insert(
          name: 'Expiring sub',
          amountCents: 999,
          direction: 'out',
          dayOfMonth: 5,
          startMonth: '2026-01',
          endMonth: const Value('2026-05'), // ended in May
          category: 'subscription',
        ),
      );

      final junEntries = await recRepo.expandForMonth(DateTime(2026, 6));
      expect(junEntries, isEmpty);

      final mayEntries = await recRepo.expandForMonth(DateTime(2026, 5));
      expect(mayEntries.length, 1);
    });

    test('expandForMonth clamps dayOfMonth to last day of month', () async {
      // Feb 2026 has 28 days; dayOfMonth=31 should clamp to 28
      await recRepo.create(
        RecurringTransactionsCompanion.insert(
          name: 'Bill',
          amountCents: 5000,
          direction: 'out',
          dayOfMonth: 31,
          startMonth: '2026-01',
          category: 'other',
        ),
      );

      final entries = await recRepo.expandForMonth(DateTime(2026, 2));
      expect(entries.first.date, '2026-02-28');
    });

    test('month boundary: Dec→Jan wraps correctly', () async {
      await recRepo.create(
        RecurringTransactionsCompanion.insert(
          name: 'Yearly',
          amountCents: 12000,
          direction: 'out',
          dayOfMonth: 1,
          startMonth: '2026-01',
          category: 'other',
        ),
      );

      final dec = await recRepo.expandForMonth(DateTime(2026, 12));
      expect(dec.first.date, '2026-12-01');

      final jan = await recRepo.expandForMonth(DateTime(2027, 1));
      expect(jan.first.date, '2027-01-01');
    });
  });

  // ── DebtRepository ────────────────────────────────────────────────────────

  group('DebtRepository', () {
    test('CRUD', () async {
      final id = await debtRepo.create(
        DebtsCompanion.insert(
          person: 'Alice',
          amountCents: 5000,
          direction: 'owes_me',
        ),
      );

      final debts = await debtRepo.watchAll().first;
      expect(debts.length, 1);
      expect(debts.first.settled, false);

      await debtRepo.delete(id);
      expect(await debtRepo.watchAll().first, isEmpty);
    });

    test('settle flow', () async {
      final id = await debtRepo.create(
        DebtsCompanion.insert(
          person: 'Bob',
          amountCents: 2000,
          direction: 'i_owe',
        ),
      );

      await debtRepo.settle(id);

      final unsettled = await debtRepo.watchAll().first;
      final settled = await debtRepo.watchSettled().first;
      expect(unsettled, isEmpty);
      expect(settled.length, 1);
      expect(settled.first.settled, true);
    });

    test('reopen restores unsettled state', () async {
      final id = await debtRepo.create(
        DebtsCompanion.insert(
          person: 'Carol',
          amountCents: 3000,
          direction: 'owes_me',
        ),
      );
      await debtRepo.settle(id);
      await debtRepo.reopen(id);

      final unsettled = await debtRepo.watchAll().first;
      expect(unsettled.length, 1);
      expect(unsettled.first.settled, false);
    });
  });
}
