import 'nutrition_profile.dart';

class DailyMacroTarget {
  const DailyMacroTarget({
    required this.targetCalories,
    required this.targetProteinGrams,
  });

  final int targetCalories;
  final int targetProteinGrams;
}

class NutritionCalculator {
  const NutritionCalculator();

  /// Calculates daily target calories & protein for a specific day context.
  DailyMacroTarget computeDailyTarget({
    required NutritionProfile profile,
    required bool isGymDay,
    required bool isPeriodDay,
  }) {
    if (!profile.isComplete) {
      // Fallback defaults if profile is missing
      return DailyMacroTarget(
        targetCalories: isGymDay ? 1800 : 1500,
        targetProteinGrams: isGymDay ? 120 : 90,
      );
    }

    final w = profile.weightKg!;
    final h = profile.heightCm!;
    final a = profile.age!;
    final isFemale = profile.gender?.toLowerCase() != 'male';

    // Mifflin-St Jeor BMR Equation
    final bmr = isFemale
        ? (10 * w) + (6.25 * h) - (5 * a) - 161
        : (10 * w) + (6.25 * h) - (5 * a) + 5;

    double baseCalories;
    switch (profile.fitnessGoal) {
      case FitnessGoal.lose:
        // Weight loss: Baseline ~ BMR - 140 kcal (minimum 1200 for women)
        baseCalories = (bmr - 139).clamp(isFemale ? 1200.0 : 1500.0, 3500.0);
        break;
      case FitnessGoal.maintain:
        baseCalories = bmr * 1.3;
        break;
      case FitnessGoal.gain:
        baseCalories = (bmr * 1.3) + 300.0;
        break;
    }

    // Gym day boost (+300 kcal for exercise burn)
    if (isGymDay) {
      baseCalories += 300.0;
    }

    // Period week buffer (+100 kcal)
    if (isPeriodDay) {
      baseCalories += 100.0;
    }

    // Protein calculation: 1.8g to 2.0g per kg for Gym/Lose, 1.5g for rest
    final proteinRatio = isGymDay || profile.fitnessGoal == FitnessGoal.lose
        ? 1.9
        : 1.5;
    final targetProtein = (w * proteinRatio).round().clamp(60, 220);

    return DailyMacroTarget(
      targetCalories: baseCalories.round(),
      targetProteinGrams: targetProtein,
    );
  }
}
