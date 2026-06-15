import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_planner/core/db/database.dart';
import 'package:personal_planner/features/finance/widgets/forecast_card.dart';
import 'package:personal_planner/features/finance/widgets/quick_add_sheet.dart';
import 'package:personal_planner/features/finance/widgets/transaction_tile.dart';

Widget _wrap(Widget child, AppDatabase db) => ProviderScope(
  overrides: [appDatabaseProvider.overrideWithValue(db)],
  child: MaterialApp(home: child),
);

AppDatabase _openDb() => AppDatabase(NativeDatabase.memory());

void main() {
  // ── ForecastCard renders seeded data ─────────────────────────────────────

  testWidgets('ForecastCard shows estimated balance', (tester) async {
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

    await tester.pumpWidget(
      _wrap(Scaffold(body: ForecastCard(month: DateTime(2026, 6))), db),
    );
    await tester.pumpAndSettle();

    expect(find.text('Est. End-of-Month'), findsOneWidget);
    // Net = 200000 - 5000 = 195000 cents = €1950.00
    expect(find.textContaining('1,950'), findsWidgets);
  });

  // ── QuickAddSheet creates a transaction row ────────────────────────────────

  testWidgets('QuickAddSheet creates a transaction', (tester) async {
    final db = _openDb();
    addTearDown(db.close);

    await tester.pumpWidget(
      _wrap(
        Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => QuickAddSheet.show(ctx),
              child: const Text('Open'),
            ),
          ),
        ),
        db,
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Fill amount
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Amount (€)'),
      '12.50',
    );
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    final txs = await db.select(db.transactions).get();
    expect(txs.length, 1);
    expect(txs.first.amountCents, 1250);
    expect(txs.first.direction, 'out');
    expect(txs.first.status, 'actual');
  });

  // ── Planned → actual conversion ───────────────────────────────────────────

  testWidgets('TransactionTile converts planned to actual on tap', (
    tester,
  ) async {
    final db = _openDb();
    addTearDown(db.close);

    final id = await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            date: '2026-06-15',
            amountCents: 3000,
            direction: 'out',
            status: 'planned',
            category: 'shopping',
          ),
        );

    final tx = await (db.select(
      db.transactions,
    )..where((t) => t.id.equals(id))).getSingle();

    await tester.pumpWidget(
      _wrap(Scaffold(body: TransactionTile(transaction: tx)), db),
    );
    await tester.pumpAndSettle();

    // Planned transaction shows the check-circle button
    await tester.tap(find.byIcon(Icons.check_circle_outline));
    await tester.pumpAndSettle();

    final updated = await (db.select(
      db.transactions,
    )..where((t) => t.id.equals(id))).getSingle();
    expect(updated.status, 'actual');
  });
}
