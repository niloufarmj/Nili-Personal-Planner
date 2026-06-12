import 'package:drift/drift.dart';

import '../converters/json_map_converter.dart';
import '../converters/string_list_converter.dart';

/// Gym workout plan definitions (A/B/C plan content).
class WorkoutPlans extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get content => text()(); // markdown
}

/// Individual gym sessions — planned and actual.
class GymSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get date => text()(); // YYYY-MM-DD
  IntColumn get planId => integer().nullable().references(WorkoutPlans, #id)();
  TextColumn get status => text()(); // 'planned'|'done'|'missed'
  TextColumn get startTime => text().nullable()();
  IntColumn get durationMin => integer().nullable()();
  TextColumn get notes => text().nullable()();
}

/// Body measurements over time.
class Measurements extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get date => text()(); // YYYY-MM-DD
  RealColumn get weightKg => real().nullable()();
  TextColumn get fields => text().nullable().map(
    const NullAwareTypeConverter.wrap(JsonMapConverter()),
  )(); // {waist_cm,...}
  TextColumn get photos => text().nullable().map(
    const NullAwareTypeConverter.wrap(StringListConverter()),
  )();
}

/// Fitness goals with deadlines.
class FitnessGoals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get metric => text()();
  RealColumn get target => real()();
  TextColumn get direction => text().withDefault(const Constant('up'))(); // 'up'|'down'
  TextColumn get deadline => text().nullable()();
  TextColumn get achievedDate => text().nullable()();
}

/// Daily habit definitions.
class Habits extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get targetPerDay => integer().withDefault(const Constant(1))();
  TextColumn get reminderTimes => text().nullable().map(
    const NullAwareTypeConverter.wrap(StringListConverter()),
  )(); // ['09:00',...]
  BoolColumn get active => boolean().withDefault(const Constant(true))();
}

/// Log of daily habit completions.
class HabitLogs extends Table {
  IntColumn get habitId => integer().references(Habits, #id)();
  TextColumn get date => text()(); // YYYY-MM-DD
  IntColumn get count => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {habitId, date};
}
