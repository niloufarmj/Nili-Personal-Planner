import 'package:flutter_test/flutter_test.dart';
import 'package:personal_planner/main.dart';

void main() {
  testWidgets('app smoke test', (tester) async {
    await tester.pumpWidget(const PersonalPlannerApp());
    expect(find.byType(PersonalPlannerApp), findsOneWidget);
  });
}
