import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
    Measurements,
    FitnessGoals,
    Habits,
    HabitLogs,
    // Wellbeing
    WellbeingActions,
    WellbeingLogs,
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
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'app.db'));
      return NativeDatabase.createInBackground(file);
    });
  }

  @override
  int get schemaVersion => 3;

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
    },
  );
}

/// Riverpod provider — overridden in main.dart with a real instance.
final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('appDatabaseProvider must be overridden'),
);
