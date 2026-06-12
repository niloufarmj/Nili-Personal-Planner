import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_planner/core/db/database.dart';
import 'package:personal_planner/core/design/design.dart';
import 'package:personal_planner/features/lists/lists_screen.dart';
import 'package:personal_planner/features/lists/repositories/collection_repository.dart';

// Use MaterialApp(home:) — GoRouter adds its own RouterDelegate timers that
// cannot be flushed inside FakeAsync, causing test failures. Navigation from
// collection-card taps is not exercised by these tests so GoRouter is unneeded.
Widget _wrap(Widget child, AppDatabase db) => ProviderScope(
  overrides: [appDatabaseProvider.overrideWithValue(db)],
  child: MaterialApp(home: child),
);

/// Pumps one extra millisecond to fire drift's zero-duration stream-cleanup
/// timers, then replaces the widget tree with an empty widget so the
/// ProviderScope is unmounted before the test framework's invariant check.
/// Must be called at the END of every test body (not in addTearDown, because
/// addTearDown runs after FakeAsync exits and tester.pump() would block).
Future<void> _disposeAndFlush(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox()); // unmount → schedules 0-timer
  await tester.pump(const Duration(milliseconds: 1)); // fire 0-timer
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  testWidgets('empty state renders when no collections', (tester) async {
    await tester.pumpWidget(_wrap(const ListsScreen(), db));
    await tester.pump();

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('All your lists in one place'), findsOneWidget);

    await _disposeAndFlush(tester);
  });

  testWidgets('grid shows collection after it is created', (tester) async {
    final repo = CollectionRepository(db);
    await repo.create(name: 'My Chores', template: 'chore');

    await tester.pumpWidget(_wrap(const ListsScreen(), db));
    await tester.pump();

    expect(find.text('My Chores'), findsOneWidget);
    expect(find.byType(EmptyState), findsNothing);

    await _disposeAndFlush(tester);
  });

  testWidgets('FAB tap opens new-list sheet', (tester) async {
    await tester.pumpWidget(_wrap(const ListsScreen(), db));
    await tester.pump();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('New list'), findsOneWidget);

    await _disposeAndFlush(tester);
  });

  testWidgets('creating a collection from sheet shows it in grid', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const ListsScreen(), db));
    await tester.pump();

    // Open sheet
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // Enter name
    await tester.enterText(find.byType(TextField), 'Iran Shopping');
    await tester.tap(find.text('Next: pick template'));
    await tester.pumpAndSettle();

    // Pick template
    final shoppingFinder = find.text('Shopping');
    await tester.ensureVisible(shoppingFinder);
    await tester.tap(shoppingFinder);
    await tester.pumpAndSettle();

    expect(find.text('Iran Shopping'), findsOneWidget);

    await _disposeAndFlush(tester);
  });
}
