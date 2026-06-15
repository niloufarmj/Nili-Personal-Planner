import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_planner/core/db/database.dart';
import 'package:personal_planner/features/finance/models/projected_entry.dart';
import 'package:personal_planner/features/finance/services/forecast_service.dart';

AppDatabase _openDb() => AppDatabase(NativeDatabase.memory());

// ── Helpers to build synthetic transactions ────────────────────────────────────

Transaction _tx({
  int id = 0,
  required String date,
  required int amountCents,
  required String direction,
  required String status,
  String category = 'food',
}) => Transaction(
  id: id,
  date: date,
  amountCents: amountCents,
  direction: direction,
  status: status,
  category: category,
  note: null,
  itemId: null,
  tripId: null,
);

ProjectedEntry _proj({
  required String date,
  required int amountCents,
  required String direction,
  String category = 'rent',
}) => ProjectedEntry(
  amountCents: amountCents,
  direction: direction,
  category: category,
  date: date,
  name: 'Recurring',
  recurringId: 1,
);

void main() {
  // ── Empty month ─────────────────────────────────────────────────────────────

  test('empty month returns all zeros', () {
    final result = ForecastService.compute(
      transactions: [],
      projected: [],
      today: DateTime(2026, 6, 11),
    );
    expect(result.actualInCents, 0);
    expect(result.actualOutCents, 0);
    expect(result.estimatedEndBalanceCents, 0);
  });

  // ── Actual-only month ─────────────────────────────────────────────────────────

  test('actual income minus actual expenses', () {
    final result = ForecastService.compute(
      transactions: [
        _tx(
          date: '2026-06-05',
          amountCents: 200000,
          direction: 'in',
          status: 'actual',
          category: 'income',
        ),
        _tx(
          date: '2026-06-10',
          amountCents: 5000,
          direction: 'out',
          status: 'actual',
          category: 'food',
        ),
      ],
      projected: [],
      today: DateTime(2026, 6, 11),
    );
    expect(result.actualInCents, 200000);
    expect(result.actualOutCents, 5000);
    expect(result.actualNetCents, 195000);
    expect(result.estimatedEndBalanceCents, 195000);
  });

  // ── Planned transactions ──────────────────────────────────────────────────────

  test('planned transactions count in estimate but not actual', () {
    final result = ForecastService.compute(
      transactions: [
        _tx(
          date: '2026-06-05',
          amountCents: 200000,
          direction: 'in',
          status: 'actual',
          category: 'income',
        ),
        _tx(
          date: '2026-06-20',
          amountCents: 30000,
          direction: 'out',
          status: 'planned',
          category: 'rent',
        ),
      ],
      projected: [],
      today: DateTime(2026, 6, 11),
    );
    expect(result.actualInCents, 200000);
    expect(result.plannedOutCents, 30000);
    expect(result.estimatedEndBalanceCents, 200000 - 30000);
  });

  // ── Projected recurring remainder ─────────────────────────────────────────────

  test('projected entries after today contribute to estimate', () {
    final result = ForecastService.compute(
      transactions: [],
      projected: [
        _proj(
          date: '2026-06-15',
          amountCents: 70000,
          direction: 'out',
        ), // future
        _proj(date: '2026-06-01', amountCents: 200000, direction: 'in'), // past
      ],
      today: DateTime(2026, 6, 11),
    );
    // Past projected entry (Jun 1) is NOT in the remainder
    expect(result.projectedRemainingOutCents, 70000);
    expect(result.projectedRemainingInCents, 0);
    expect(result.estimatedEndBalanceCents, -70000);
  });

  // ── Mid-month: mix of actual + projected + planned ────────────────────────────

  test('mid-month: actual + projected remainder + planned', () {
    final result = ForecastService.compute(
      transactions: [
        _tx(
          date: '2026-06-01',
          amountCents: 200000,
          direction: 'in',
          status: 'actual',
          category: 'income',
        ),
        _tx(
          date: '2026-06-05',
          amountCents: 8000,
          direction: 'out',
          status: 'actual',
          category: 'food',
        ),
        _tx(
          date: '2026-06-25',
          amountCents: 12000,
          direction: 'out',
          status: 'planned',
          category: 'transport',
        ),
      ],
      projected: [
        _proj(
          date: '2026-06-30',
          amountCents: 70000,
          direction: 'out',
        ), // future rent
      ],
      today: DateTime(2026, 6, 11),
    );
    // actual net: 200000 - 8000 = 192000
    // projected remaining: -70000
    // planned: -12000
    expect(result.actualNetCents, 192000);
    expect(result.projectedRemainingNetCents, -70000);
    expect(result.plannedNetCents, -12000);
    expect(result.estimatedEndBalanceCents, 192000 - 70000 - 12000);
  });

  // ── Category breakdown ────────────────────────────────────────────────────────

  test('category breakdown tracks actual and projected', () {
    final result = ForecastService.compute(
      transactions: [
        _tx(
          date: '2026-06-05',
          amountCents: 5000,
          direction: 'out',
          status: 'actual',
          category: 'food',
        ),
        _tx(
          date: '2026-06-07',
          amountCents: 3000,
          direction: 'out',
          status: 'actual',
          category: 'food',
        ),
        _tx(
          date: '2026-06-08',
          amountCents: 200000,
          direction: 'in',
          status: 'actual',
          category: 'income',
        ),
      ],
      projected: [
        _proj(
          date: '2026-06-20',
          amountCents: 70000,
          direction: 'out',
          category: 'rent',
        ),
      ],
      today: DateTime(2026, 6, 11),
    );
    expect(result.categoryBreakdown['food'], -8000); // net out
    expect(result.categoryBreakdown['income'], 200000); // net in
    expect(result.categoryBreakdown['rent'], -70000); // projected
  });

  // ── Income-heavy month ────────────────────────────────────────────────────────

  test('income-heavy month yields positive balance', () {
    final result = ForecastService.compute(
      transactions: [
        _tx(
          date: '2026-06-01',
          amountCents: 500000,
          direction: 'in',
          status: 'actual',
          category: 'income',
        ),
        _tx(
          date: '2026-06-02',
          amountCents: 1000,
          direction: 'out',
          status: 'actual',
          category: 'food',
        ),
      ],
      projected: [],
      today: DateTime(2026, 6, 11),
    );
    expect(result.estimatedEndBalanceCents, isPositive);
    expect(result.estimatedEndBalanceCents, 499000);
  });

  // ── Integration: repository + forecast ────────────────────────────────────────

  test('integration: forecast via repository round-trip', () async {
    final db = _openDb();
    addTearDown(db.close);

    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            date: '2026-06-05',
            amountCents: 200000,
            direction: 'in',
            status: 'actual',
            category: 'income',
          ),
        );
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            date: '2026-06-10',
            amountCents: 5000,
            direction: 'out',
            status: 'actual',
            category: 'food',
          ),
        );

    final txs = await (db.select(
      db.transactions,
    )..where((t) => t.date.like('2026-06-%'))).get();

    final result = ForecastService.compute(
      transactions: txs,
      projected: [],
      today: DateTime(2026, 6, 11),
    );
    expect(result.actualNetCents, 195000);
  });
}
