import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_planner/core/calendar/calendar_aggregator.dart';
import 'package:personal_planner/core/calendar/calendar_day_data.dart';
import 'package:personal_planner/core/db/database.dart';
import 'package:personal_planner/core/db/repositories/event_repository.dart';

AppDatabase _openDb() => AppDatabase(NativeDatabase.memory());

void main() {
  late AppDatabase db;
  late CalendarAggregator aggregator;

  setUp(() {
    db = _openDb();
    aggregator = CalendarAggregator(db, EventRepository(db));
  });

  tearDown(() => db.close());

  test('financeDots reflects planned transactions in range', () async {
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            date: '2026-06-20',
            amountCents: 5000,
            direction: 'out',
            status: 'planned',
            category: 'shopping',
          ),
        );
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            date: '2026-06-25',
            amountCents: 70000,
            direction: 'out',
            status: 'planned',
            category: 'rent',
          ),
        );
    // Actual transaction should NOT count as a finance dot
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            date: '2026-06-10',
            amountCents: 1000,
            direction: 'out',
            status: 'actual',
            category: 'food',
          ),
        );

    final data = await aggregator.getDataForRange(
      DateTime(2026, 6, 1),
      DateTime(2026, 6, 30),
    );

    expect(data['2026-06-20']!.financeDots, 1);
    expect(data['2026-06-25']!.financeDots, 1);
    expect(data['2026-06-10']!.financeDots, 0); // actual, not planned
  });

  test('showFinance: false suppresses finance dots', () async {
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            date: '2026-06-15',
            amountCents: 5000,
            direction: 'out',
            status: 'planned',
            category: 'shopping',
          ),
        );

    final data = await aggregator.getDataForRange(
      DateTime(2026, 6, 1),
      DateTime(2026, 6, 30),
      filter: CalendarFilter.all.copyWith(showFinance: false),
    );

    expect(data['2026-06-15']!.financeDots, 0);
  });

  test(
    'day-sheet finance section: getByDate returns transactions for date',
    () async {
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              date: '2026-06-11',
              amountCents: 2500,
              direction: 'out',
              status: 'planned',
              category: 'food',
            ),
          );

      final txs = await (db.select(
        db.transactions,
      )..where((t) => t.date.equals('2026-06-11'))).get();

      expect(txs.length, 1);
      expect(txs.first.amountCents, 2500);
    },
  );
}
