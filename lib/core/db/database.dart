import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connection/connection.dart';

import 'converters/json_map_converter.dart';
import 'converters/string_list_converter.dart';
import 'tables/chore_tables.dart';
import 'tables/core_day_tables.dart';
import 'tables/finance_tables.dart';
import 'tables/fitness_tables.dart';
import 'tables/list_engine_tables.dart';
import 'tables/meals_tables.dart';
import 'tables/settings_table.dart';
import 'tables/social_tables.dart';
import 'tables/wellbeing_tables.dart';
import 'tables/work_tables.dart';
import 'tables/period_tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    // Core day layer
    Tags,
    DayTags,
    Events,
    Trips,
    Reminders,
    // Generic list engine
    Collections,
    Items,
    Subtasks,
    ChoreCompletions,
    // Finance
    Transactions,
    RecurringTransactions,
    Debts,
    // Meals
    Ingredients,
    Recipes,
    RecipeIngredients,
    MealSlots,
    // Fitness
    WorkoutPlans,
    GymSessions,
    SportActivities,
    Measurements,
    FitnessGoals,
    Habits,
    HabitLogs,
    // Wellbeing
    WellbeingActions,
    WellbeingLogs,
    // Period
    PeriodLogs,
    // Work
    WorkContexts,
    TimeEntries,
    // Social
    SocialAccounts,
    SocialLogs,
    // Settings
    AppSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? connect());

  @override
  int get schemaVersion => 11;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(choreCompletions);
      }
      if (from < 3) {
        await m.addColumn(fitnessGoals, fitnessGoals.direction);
      }
      if (from < 4) {
        await m.createTable(periodLogs);
      }
      if (from < 5) {
        await m.addColumn(timeEntries, timeEntries.startTime);
        await m.addColumn(timeEntries, timeEntries.endTime);
        await m.addColumn(timeEntries, timeEntries.location);
      }
      if (from < 6) {
        await m.createTable(sportActivities);
      }
      if (from < 7) {
        try {
          await m.addColumn(recipes, recipes.proteinGrams);
        } catch (_) {
          // Ignore if column already added
        }
      }
      if (from < 8) {
        try {
          await m.addColumn(ingredients, ingredients.inStock);
        } catch (_) {
          // Ignore if column already added
        }
      }
      if (from < 9) {
        try {
          await m.addColumn(ingredients, ingredients.image);
        } catch (_) {}
        try {
          await m.addColumn(ingredients, ingredients.estimatedCost);
        } catch (_) {}
      }
      if (from < 10) {
        try {
          await m.addColumn(recipes, recipes.calories);
        } catch (_) {}
      }
      if (from < 11) {
        try {
          await m.addColumn(collections, collections.coverImage);
        } catch (_) {}
      }
    },
  );
}

/// Riverpod provider — overridden in main.dart with a real instance.
final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('appDatabaseProvider must be overridden'),
);
