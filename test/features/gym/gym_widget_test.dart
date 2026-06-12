import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_planner/core/db/database.dart';
import 'package:personal_planner/core/db/repositories/day_repository.dart';
import 'package:personal_planner/features/gym/gym_repository.dart';
import 'package:personal_planner/features/gym/gym_screen.dart';

Widget _wrap(Widget child, AppDatabase db) => ProviderScope(
  overrides: [appDatabaseProvider.overrideWithValue(db)],
  child: MaterialApp(home: child),
);

String _todayStr() {
  final n = DateTime.now();
  return '${n.year.toString().padLeft(4, '0')}-'
      '${n.month.toString().padLeft(2, '0')}-'
      '${n.day.toString().padLeft(2, '0')}';
}

// _runTestBody (flutter_test binding.dart:1689) calls runApp(Container(...))
// followed by pump() with no duration, which does NOT call fakeAsync.elapse.
// Drift's 0-duration cleanup timers (from StreamQueryStore.markAsClosed) are
// therefore still pending when _verifyInvariants runs at line 1703.
// Fix: replace the widget tree with SizedBox.shrink() INSIDE the test body so
// that the framework's runApp at line 1689 disposes only an empty widget.
Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  // Advance time so fake_async fires Drift's 0-duration cleanup timers.
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  // ── One-tap "Done today" ──────────────────────────────────────────────

  testWidgets('GymScreen FAB opens log sheet', (tester) async {
    await tester.pumpWidget(_wrap(const GymScreen(), db));
    await tester.pumpAndSettle();

    expect(find.text('Done today'), findsOneWidget);
    await tester.tap(find.text('Done today'));
    await tester.pumpAndSettle();

    expect(find.text('Log gym session'), findsOneWidget);

    // Dispose stream providers before framework cleanup (see _disposeTree).
    await _disposeTree(tester);
  });

  testWidgets('log sheet Mark done button saves session', (tester) async {
    await WorkoutPlanRepository(db).seedDefaultPlansIfNeeded();
    await tester.pumpWidget(_wrap(const GymScreen(), db));
    await tester.pumpAndSettle();

    // Open sheet
    await tester.tap(find.text('Done today'));
    await tester.pumpAndSettle();

    // Tap Mark done
    await tester.tap(find.text('Mark done'));
    await tester.pumpAndSettle();

    final sessions = await db.select(db.gymSessions).get();
    expect(sessions.length, 1);
    expect(sessions.first.status, 'done');
    expect(sessions.first.date, _todayStr());

    await _disposeTree(tester);
  });

  // ── Calendar aggregator: planned vs done dots ─────────────────────────────

  testWidgets('DayDetailGymSection shows planned session with Done button', (
    tester,
  ) async {
    final today = _todayStr();
    await db
        .into(db.gymSessions)
        .insert(GymSessionsCompanion.insert(date: today, status: 'planned'));

    await tester.pumpWidget(_wrap(DayDetailGymSection(date: today), db));
    await tester.pumpAndSettle();

    expect(find.text('Planned session'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('DayDetailGymSection shows done session without Done button', (
    tester,
  ) async {
    final today = _todayStr();
    await db
        .into(db.gymSessions)
        .insert(
          GymSessionsCompanion.insert(
            date: today,
            status: 'done',
            durationMin: const Value(45),
          ),
        );

    await tester.pumpWidget(_wrap(DayDetailGymSection(date: today), db));
    await tester.pumpAndSettle();

    expect(find.textContaining('Session done'), findsOneWidget);
    expect(find.text('Done'), findsNothing);
  });

  testWidgets(
    'DayDetailGymSection shows travel warning on travel-tagged days',
    (tester) async {
      final today = _todayStr();
      final dayRepo = DayRepository(db);
      await dayRepo.seedDefaultTagsIfNeeded();
      final tags = await dayRepo.getAllTags();
      final travel = tags.firstWhere((t) => t.name == 'travel');
      await dayRepo.setTag(today, travel.id);

      await tester.pumpWidget(_wrap(DayDetailGymSection(date: today), db));
      await tester.pumpAndSettle();

      expect(find.textContaining('Travel day'), findsOneWidget);
    },
  );
}
