import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_planner/core/db/database.dart';
import 'package:personal_planner/core/design/design.dart';
import 'package:personal_planner/core/router/app_router.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(AppDatabase db) => ProviderScope(
  overrides: [
    appDatabaseProvider.overrideWithValue(db),
  ],
  child: MaterialApp.router(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    routerConfig: buildAppRouter(),
  ),
);

Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('Today tab renders on launch', (tester) async {
    await tester.pumpWidget(_app(db));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Today'), findsWidgets);
    await _disposeTree(tester);
  });

  testWidgets('All 5 bottom-nav tabs are present', (tester) async {
    await tester.pumpWidget(_app(db));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Today'), findsWidgets);
    expect(find.text('Calendar'), findsWidgets);
    expect(find.text('Lists'), findsWidgets);
    expect(find.text('Track'), findsWidgets);
    expect(find.text('More'), findsWidgets);
    await _disposeTree(tester);
  });

  testWidgets('Tap Calendar tab navigates to CalendarScreen', (tester) async {
    await tester.pumpWidget(_app(db));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Calendar'), findsWidgets);
    await _disposeTree(tester);
  });

  testWidgets('Tap Lists tab navigates to ListsScreen', (tester) async {
    await tester.pumpWidget(_app(db));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byIcon(Icons.list_outlined));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('All your lists in one place'), findsOneWidget);
    await _disposeTree(tester);
  });

  testWidgets('Tap Track tab navigates to TrackScreen', (tester) async {
    await tester.pumpWidget(_app(db));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byIcon(Icons.bar_chart_outlined));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Track'), findsWidgets);
    expect(find.text('Finance'), findsOneWidget);
    await _disposeTree(tester);
  });

  testWidgets('Tap More tab navigates to MoreScreen', (tester) async {
    await tester.pumpWidget(_app(db));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Travel Planner'), findsOneWidget);
    await _disposeTree(tester);
  });

  testWidgets('No exceptions across all 5 tabs', (tester) async {
    await tester.pumpWidget(_app(db));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    for (final icon in [
      Icons.calendar_month_outlined,
      Icons.list_outlined,
      Icons.bar_chart_outlined,
      Icons.more_horiz,
      Icons.today_outlined,
    ]) {
      await tester.tap(find.byIcon(icon));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    await _disposeTree(tester);
  });
}
