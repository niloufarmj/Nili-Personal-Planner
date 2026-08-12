import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/db/database.dart';
import 'core/db/repositories/day_repository.dart';
import 'core/design/design.dart';
import 'core/router/app_router.dart';
import 'features/finance/repositories/debt_repository.dart';
import 'features/fitness/fitness_repository.dart';
import 'features/gym/gym_repository.dart';
import 'features/habits/habit_repository.dart';
import 'features/lists/repositories/collection_repository.dart';
import 'features/lists/repositories/item_repository.dart';
import 'features/meals/ingredient_repository.dart';
import 'features/meals/meal_slot_repository.dart';
import 'features/meals/recipe_repository.dart';
import 'features/settings/seed/services/seeder_service.dart';
import 'features/wellbeing/wellbeing_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase();

  // One-time seeds (idempotent)
  await DayRepository(db).seedDefaultTagsIfNeeded();
  await WorkoutPlanRepository(db).seedDefaultPlansIfNeeded();
  await CollectionRepository(db).seedDefaultCollectionsIfNeeded();
  await HabitRepository(db).seedDefaultHabitsIfNeeded();
  await WellbeingRepository(db).seedDefaultActionsIfNeeded();
  await RecipeRepository(db).seedDefaultRecipesIfNeeded(
    IngredientRepository(db),
    MealSlotRepository(db),
  );

  // Auto-seed data from seed.json if database seed_version is outdated
  final versionRow = await (db.select(db.appSettings)..where((s) => s.key.equals('seed_version'))).getSingleOrNull();
  final currentVersion = int.tryParse(versionRow?.value ?? '') ?? 0;
  if (currentVersion < 5) {
    try {
      final jsonStr = await rootBundle.loadString('assets/seeds/seed.json');
      final seeder = SeederService(
        db: db,
        dayRepo: DayRepository(db),
        collectionRepo: CollectionRepository(db),
        itemRepo: ItemRepository(db),
        ingredientRepo: IngredientRepository(db),
        recipeRepo: RecipeRepository(db),
        mealSlotRepo: MealSlotRepository(db),
        planRepo: WorkoutPlanRepository(db),
        fitnessRepo: FitnessRepository(db),
        habitRepo: HabitRepository(db),
        debtRepo: DebtRepository(db),
      );
      await seeder.run(jsonStr);
    } catch (e) {
      debugPrint('Auto-seeding error: $e');
    }
  }

  runApp(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: const PersonalPlannerApp(),
    ),
  );
}

class PersonalPlannerApp extends ConsumerWidget {
  const PersonalPlannerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final font = ref.watch(fontOptionProvider);

    return MaterialApp.router(
      title: 'Nili Planner',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(font),
      darkTheme: AppTheme.dark(font),
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}
