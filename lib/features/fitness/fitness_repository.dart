import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/services/notification_service.dart';

class FitnessRepository {
  const FitnessRepository(this._db);

  final AppDatabase _db;

  // ── Measurements ───────────────────────────────────────────────────────────

  Stream<List<Measurement>> watchMeasurements() {
    return (_db.select(_db.measurements)
          ..orderBy([(m) => OrderingTerm.desc(m.date)]))
        .watch();
  }

  Future<List<Measurement>> getMeasurements() {
    return (_db.select(_db.measurements)
          ..orderBy([(m) => OrderingTerm.desc(m.date)]))
        .get();
  }

  Future<int> createMeasurement(MeasurementsCompanion companion) async {
    final id = await _db.into(_db.measurements).insert(companion);
    await checkGoalAchievements();
    return id;
  }

  Future<void> updateMeasurement(Measurement measurement) async {
    await _db.update(_db.measurements).replace(measurement);
    await checkGoalAchievements();
  }

  Future<int> deleteMeasurement(int id) async {
    final deleted = await (_db.delete(_db.measurements)
          ..where((m) => m.id.equals(id)))
        .go();
    await checkGoalAchievements();
    return deleted;
  }

  // ── Goals ──────────────────────────────────────────────────────────────────

  Stream<List<FitnessGoal>> watchGoals() {
    return _db.select(_db.fitnessGoals).watch();
  }

  Future<List<FitnessGoal>> getGoals() {
    return _db.select(_db.fitnessGoals).get();
  }

  Future<int> createGoal(FitnessGoalsCompanion companion) async {
    final id = await _db.into(_db.fitnessGoals).insert(companion);
    await checkGoalAchievements();
    return id;
  }

  Future<void> updateGoal(FitnessGoal goal) async {
    await _db.update(_db.fitnessGoals).replace(goal);
    await checkGoalAchievements();
  }

  Future<int> deleteGoal(int id) {
    return (_db.delete(_db.fitnessGoals)..where((g) => g.id.equals(id))).go();
  }

  // ── Goal Achievement Detection ─────────────────────────────────────────────

  /// Scans all open goals and updates achievedDate if a measurement meets the target.
  Future<void> checkGoalAchievements() async {
    final openGoals = await (_db.select(_db.fitnessGoals)
          ..where((g) => g.achievedDate.isNull()))
        .get();
    if (openGoals.isEmpty) return;

    final measurements = await getMeasurements();
    if (measurements.isEmpty) return;

    for (final goal in openGoals) {
      // Find the latest measurement that has this metric
      Measurement? matchingMeasurement;
      double? value;

      for (final m in measurements) {
        if (goal.metric == 'weight') {
          if (m.weightKg != null) {
            matchingMeasurement = m;
            value = m.weightKg;
            break;
          }
        } else {
          // Custom field
          final customFields = m.fields;
          if (customFields != null && customFields.containsKey(goal.metric)) {
            final val = customFields[goal.metric];
            if (val is num) {
              matchingMeasurement = m;
              value = val.toDouble();
              break;
            } else if (val is String) {
              final parsed = double.tryParse(val);
              if (parsed != null) {
                matchingMeasurement = m;
                value = parsed;
                break;
              }
            }
          }
        }
      }

      if (value != null && matchingMeasurement != null) {
        final isAchieved = goal.direction == 'down'
            ? value <= goal.target
            : value >= goal.target;

        if (isAchieved) {
          await updateGoal(goal.copyWith(achievedDate: Value(matchingMeasurement.date)));
        }
      }
    }
  }

  // ── Reminders ──────────────────────────────────────────────────────────────

  /// Schedules the weekly fitness check reminder (Sundays 18:00)
  /// and the monthly photo+measurement reminder.
  Future<void> scheduleReminders() async {
    final ns = NotificationService();

    // 1. Weekly measurement reminder (ID: 241)
    // Find next Sunday at 18:00
    final now = DateTime.now();
    var nextSunday = DateTime(now.year, now.month, now.day, 18, 0);
    while (nextSunday.weekday != DateTime.sunday || nextSunday.isBefore(now)) {
      nextSunday = nextSunday.add(const Duration(days: 1));
    }
    await ns.scheduleAt(
      id: 241,
      when: nextSunday,
      title: 'Weekly Fitness Check-In',
      body: 'Time to log your weight and custom body measurements!',
    );

    // 2. Monthly photo reminder (ID: 242)
    // Next month on the same day at 10:00 AM
    var nextMonth = DateTime(now.year, now.month + 1, now.day, 10, 0);
    await ns.scheduleAt(
      id: 242,
      when: nextMonth,
      title: 'Monthly Progress Photos',
      body: 'Take your progress photos to stay motivated and track visual changes!',
    );
  }
}

final fitnessRepositoryProvider = Provider<FitnessRepository>(
  (ref) => FitnessRepository(ref.watch(appDatabaseProvider)),
);
