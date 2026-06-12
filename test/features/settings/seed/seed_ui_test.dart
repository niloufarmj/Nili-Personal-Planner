import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_planner/core/db/database.dart';
import 'package:personal_planner/core/design/design.dart';
import 'package:personal_planner/features/more/more_screen.dart';
import 'package:personal_planner/features/settings/seed/services/seeder_service.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSeederService implements SeederService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<SeedSummary> run(String seedJsonString) async {
    await Future.delayed(const Duration(milliseconds: 50));
    return SeedSummary(
      tagsInserted: 1,
      tagsUpdated: 2,
      tagsSkipped: 3,
      collectionsInserted: 4,
      collectionsUpdated: 5,
      collectionsSkipped: 6,
      itemsInserted: 7,
      itemsUpdated: 8,
      itemsSkipped: 9,
      ingredientsInserted: 10,
      ingredientsUpdated: 11,
      ingredientsSkipped: 12,
      plansInserted: 13,
      plansUpdated: 14,
      plansSkipped: 15,
      measurementsInserted: 16,
      measurementsUpdated: 17,
      measurementsSkipped: 18,
      goalsInserted: 19,
      goalsUpdated: 20,
      goalsSkipped: 21,
      habitsInserted: 22,
      habitsUpdated: 23,
      habitsSkipped: 24,
      debtsInserted: 25,
      debtsUpdated: 26,
      debtsSkipped: 27,
      warnings: ['Mock UI Warning 1', 'Mock UI Warning 2'],
    );
  }
}

class MockAssetBundle extends Fake implements AssetBundle {
  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (key == 'assets/seeds/seed.json') {
      return '{}';
    }
    throw FlutterError('Asset not found: $key');
  }
}

Widget _testApp({
  required bool debugEnabled,
  required AppDatabase database,
  SeederService? mockSeeder,
}) {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      debugSeedingEnabledProvider.overrideWithValue(debugEnabled),
      if (mockSeeder != null)
        seederServiceProvider.overrideWithValue(mockSeeder),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: DefaultAssetBundle(
        bundle: MockAssetBundle(),
        child: const Scaffold(body: MoreScreen()),
      ),
    ),
  );
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

  testWidgets(
    'Load seed data tile is absent when debugSeedingEnabled is false',
    (tester) async {
      await tester.pumpWidget(_testApp(debugEnabled: false, database: db));
      await tester.pumpAndSettle();

      expect(find.text('Load seed data'), findsNothing);
    },
  );

  testWidgets(
    'Load seed data tile is present and triggers flow when debugSeedingEnabled is true',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final mockSeeder = MockSeederService();

      await tester.pumpWidget(
        _testApp(debugEnabled: true, database: db, mockSeeder: mockSeeder),
      );
      await tester.pumpAndSettle();

      // Verify tile is present by scrolling to it
      final tileFinder = find.text('Load seed data');
      await tester.scrollUntilVisible(tileFinder, 100.0);
      expect(tileFinder, findsOneWidget);

      // Tap tile
      await tester.tap(tileFinder);
      await tester.pumpAndSettle();

      // Verify ConfirmDialog is shown
      expect(find.text('Load Seed Data?'), findsOneWidget);
      expect(find.text('Load'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Tap Load to confirm
      await tester.tap(find.text('Load'));
      await tester.pump(); // starts loading and runs parser/seeder
      await tester.pump(); // allow loader dialog route to push and render

      // Verify progress indicator is shown
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump(
        const Duration(milliseconds: 50),
      ); // let the run future complete
      await tester
          .pumpAndSettle(); // finish seeder execution and dismiss progress

      // Verify summary sheet renders correct values
      expect(find.text('Seed Data Summary'), findsOneWidget);
      expect(find.text('+1 ins, 2 upd, 3 skip'), findsOneWidget); // Tags
      expect(find.text('+4 ins, 5 upd, 6 skip'), findsOneWidget); // Collections
      expect(find.text('+7 ins, 8 upd, 9 skip'), findsOneWidget); // Items
      expect(
        find.text('+10 ins, 11 upd, 12 skip'),
        findsOneWidget,
      ); // Ingredients
      expect(find.text('+13 ins, 14 upd, 15 skip'), findsOneWidget); // Plans
      expect(
        find.text('+16 ins, 17 upd, 18 skip'),
        findsOneWidget,
      ); // Measurements
      expect(find.text('+19 ins, 20 upd, 21 skip'), findsOneWidget); // Goals
      expect(find.text('+22 ins, 23 upd, 24 skip'), findsOneWidget); // Habits
      expect(find.text('+25 ins, 26 upd, 27 skip'), findsOneWidget); // Debts

      // Verify warning list items are shown
      expect(find.text('• Mock UI Warning 1'), findsOneWidget);
      expect(find.text('• Mock UI Warning 2'), findsOneWidget);

      // Tap close button on summary sheet
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      // Summary sheet is dismissed
      expect(find.text('Seed Data Summary'), findsNothing);
    },
  );
}
