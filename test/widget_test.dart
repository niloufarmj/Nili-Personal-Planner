import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_planner/core/db/database.dart';
import 'package:personal_planner/main.dart';

void main() {
  testWidgets('app smoke test', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(
            AppDatabase(NativeDatabase.memory()),
          ),
        ],
        child: const PersonalPlannerApp(),
      ),
    );
    expect(find.byType(PersonalPlannerApp), findsOneWidget);
  });
}
