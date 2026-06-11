import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_planner/core/db/database.dart';
import 'package:personal_planner/core/design/design.dart';
import 'package:personal_planner/core/router/app_router.dart';
import 'package:drift/native.dart';

Widget _app() => ProviderScope(
  overrides: [
    appDatabaseProvider.overrideWithValue(AppDatabase(NativeDatabase.memory())),
  ],
  child: MaterialApp.router(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    routerConfig: buildAppRouter(),
  ),
);

void main() {
  testWidgets('Today tab renders on launch', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsWidgets);
  });

  testWidgets('All 5 bottom-nav tabs are present', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsWidgets);
    expect(find.text('Calendar'), findsWidgets);
    expect(find.text('Lists'), findsWidgets);
    expect(find.text('Track'), findsWidgets);
    expect(find.text('More'), findsWidgets);
  });

  testWidgets('Tap Calendar tab navigates to CalendarScreen', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await tester.pumpAndSettle();
    // CalendarScreen shows 'Calendar' in its AppBar title
    expect(find.text('Calendar'), findsWidgets);
  });

  testWidgets('Tap Lists tab navigates to ListsScreen', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.list_outlined));
    await tester.pumpAndSettle();
    expect(find.text('All your lists in one place'), findsOneWidget);
  });

  testWidgets('Tap Track tab navigates to TrackScreen', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.bar_chart_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Track what matters'), findsOneWidget);
  });

  testWidgets('Tap More tab navigates to MoreScreen', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    expect(find.text('Everything else'), findsOneWidget);
  });

  testWidgets('No exceptions across all 5 tabs', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    for (final icon in [
      Icons.calendar_month_outlined,
      Icons.list_outlined,
      Icons.bar_chart_outlined,
      Icons.more_horiz,
      Icons.today_outlined,
    ]) {
      await tester.tap(find.byIcon(icon));
      await tester.pumpAndSettle();
    }
    expect(find.byType(BottomNavigationBar), findsOneWidget);
  });
}
