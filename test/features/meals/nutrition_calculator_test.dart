import 'package:flutter_test/flutter_test.dart';
import 'package:personal_planner/features/meals/nutrition_calculator.dart';
import 'package:personal_planner/features/meals/nutrition_profile.dart';

void main() {
  group('NutritionCalculator', () {
    const calc = NutritionCalculator();

    test('User exact example: 26yo female, 160cm, 63kg, lose goal', () {
      const profile = NutritionProfile(
        age: 26,
        gender: 'female',
        heightCm: 160,
        weightKg: 63,
        fitnessGoal: FitnessGoal.lose,
      );

      // Non-gym day
      final restDayTarget = calc.computeDailyTarget(
        profile: profile,
        isGymDay: false,
        isPeriodDay: false,
      );

      expect(restDayTarget.targetCalories, equals(1200));

      // Gym day (+300 kcal boost)
      final gymDayTarget = calc.computeDailyTarget(
        profile: profile,
        isGymDay: true,
        isPeriodDay: false,
      );

      expect(gymDayTarget.targetCalories, equals(1500));
      expect(gymDayTarget.targetProteinGrams, greaterThanOrEqualTo(110));
    });

    test('Period day buffer (+100 kcal)', () {
      const profile = NutritionProfile(
        age: 26,
        gender: 'female',
        heightCm: 160,
        weightKg: 63,
        fitnessGoal: FitnessGoal.lose,
      );

      final periodTarget = calc.computeDailyTarget(
        profile: profile,
        isGymDay: false,
        isPeriodDay: true,
      );

      expect(periodTarget.targetCalories, equals(1300));
    });

    test('Incomplete profile fallback targets', () {
      const emptyProfile = NutritionProfile(
        age: null,
        gender: null,
        heightCm: null,
        weightKg: null,
        fitnessGoal: FitnessGoal.maintain,
      );

      final fallback = calc.computeDailyTarget(
        profile: emptyProfile,
        isGymDay: false,
        isPeriodDay: false,
      );

      expect(fallback.targetCalories, equals(1500));
      expect(fallback.targetProteinGrams, equals(90));
    });
  });
}
