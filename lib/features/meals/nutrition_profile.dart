import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fitness/fitness_repository.dart';

enum FitnessGoal { lose, maintain, gain }

class NutritionProfile {
  const NutritionProfile({
    required this.age,
    required this.gender,
    required this.heightCm,
    required this.weightKg,
    required this.fitnessGoal,
  });

  final int? age; // e.g. 26
  final String? gender; // 'female' | 'male'
  final double? heightCm; // e.g. 160.0
  final double? weightKg; // e.g. 63.0
  final FitnessGoal fitnessGoal; // default maintain

  bool get isComplete =>
      age != null &&
      age! > 0 &&
      gender != null &&
      heightCm != null &&
      heightCm! > 0 &&
      weightKg != null &&
      weightKg! > 0;

  NutritionProfile copyWith({
    int? age,
    String? gender,
    double? heightCm,
    double? weightKg,
    FitnessGoal? fitnessGoal,
  }) {
    return NutritionProfile(
      age: age ?? this.age,
      gender: gender ?? this.gender,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      fitnessGoal: fitnessGoal ?? this.fitnessGoal,
    );
  }
}

class NutritionProfileRepository {
  static const _keyAge = 'nutrition_profile_age';
  static const _keyGender = 'nutrition_profile_gender';
  static const _keyHeight = 'nutrition_profile_height';
  static const _keyWeight = 'nutrition_profile_weight';
  static const _keyGoal = 'nutrition_profile_goal';

  Future<NutritionProfile> loadProfile([FitnessRepository? fitRepo]) async {
    final prefs = await SharedPreferences.getInstance();
    final age = prefs.getInt(_keyAge);
    final gender = prefs.getString(_keyGender);
    final height = prefs.getDouble(_keyHeight);
    double? weight = prefs.getDouble(_keyWeight);
    final goalStr = prefs.getString(_keyGoal);

    FitnessGoal goal = FitnessGoal.maintain;
    if (goalStr == 'lose') goal = FitnessGoal.lose;
    if (goalStr == 'gain') goal = FitnessGoal.gain;

    // Sync weight and goal direction from Fitness Tracker if available
    if (fitRepo != null) {
      try {
        final measurements = await fitRepo.getMeasurements();
        if (measurements.isNotEmpty && measurements.first.weightKg != null) {
          weight = measurements.first.weightKg;
        }

        final goals = await fitRepo.getGoals();
        final weightGoal = goals.where((g) => g.metric == 'weight' && g.achievedDate == null).firstOrNull;
        if (weightGoal != null) {
          if (weightGoal.direction == 'down') goal = FitnessGoal.lose;
          if (weightGoal.direction == 'up') goal = FitnessGoal.gain;
        }
      } catch (_) {}
    }

    return NutritionProfile(
      age: age,
      gender: gender,
      heightCm: height,
      weightKg: weight,
      fitnessGoal: goal,
    );
  }

  Future<void> saveProfile(NutritionProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    if (profile.age != null) await prefs.setInt(_keyAge, profile.age!);
    if (profile.gender != null) await prefs.setString(_keyGender, profile.gender!);
    if (profile.heightCm != null) await prefs.setDouble(_keyHeight, profile.heightCm!);
    if (profile.weightKg != null) await prefs.setDouble(_keyWeight, profile.weightKg!);
    await prefs.setString(_keyGoal, profile.fitnessGoal.name);
  }
}

final nutritionProfileRepositoryProvider = Provider((ref) => NutritionProfileRepository());

final nutritionProfileProvider = FutureProvider<NutritionProfile>((ref) async {
  final repo = ref.watch(nutritionProfileRepositoryProvider);
  final fitRepo = ref.watch(fitnessRepositoryProvider);
  return repo.loadProfile(fitRepo);
});
