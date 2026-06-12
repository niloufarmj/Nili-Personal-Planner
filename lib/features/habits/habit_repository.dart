import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/services/notification_service.dart';

class HabitRepository {
  const HabitRepository(this._db);

  final AppDatabase _db;

  // ── Habit CRUD ─────────────────────────────────────────────────────────────

  Stream<List<Habit>> watchActiveHabits() {
    return (_db.select(
      _db.habits,
    )..where((h) => h.active.equals(true))).watch();
  }

  Stream<List<Habit>> watchAllHabits() {
    return _db.select(_db.habits).watch();
  }

  Future<List<Habit>> getActiveHabits() {
    return (_db.select(_db.habits)..where((h) => h.active.equals(true))).get();
  }

  Future<int> createHabit(HabitsCompanion companion) async {
    final id = await _db.into(_db.habits).insert(companion);
    await scheduleHabitReminders();
    return id;
  }

  Future<void> updateHabit(Habit habit) async {
    await _db.update(_db.habits).replace(habit);
    await scheduleHabitReminders();
  }

  Future<int> deleteHabit(int id) async {
    final deleted = await (_db.delete(
      _db.habits,
    )..where((h) => h.id.equals(id))).go();
    await scheduleHabitReminders();
    return deleted;
  }

  // ── Logging count ──────────────────────────────────────────────────────────

  Stream<List<HabitLog>> watchLogsForDate(String dateIso) {
    return (_db.select(
      _db.habitLogs,
    )..where((l) => l.date.equals(dateIso))).watch();
  }

  Future<HabitLog?> getLog(int habitId, String dateIso) {
    return (_db.select(_db.habitLogs)
          ..where((l) => l.habitId.equals(habitId) & l.date.equals(dateIso)))
        .getSingleOrNull();
  }

  Future<void> incrementCount(int habitId, String dateIso) async {
    final log = await getLog(habitId, dateIso);
    if (log != null) {
      await (_db.update(_db.habitLogs)
            ..where((l) => l.habitId.equals(habitId) & l.date.equals(dateIso)))
          .write(HabitLogsCompanion(count: Value(log.count + 1)));
    } else {
      await _db
          .into(_db.habitLogs)
          .insert(
            HabitLogsCompanion.insert(
              habitId: habitId,
              date: dateIso,
              count: const Value(1),
            ),
          );
    }
  }

  Future<void> decrementCount(int habitId, String dateIso) async {
    final log = await getLog(habitId, dateIso);
    if (log == null || log.count <= 0) return;

    await (_db.update(_db.habitLogs)
          ..where((l) => l.habitId.equals(habitId) & l.date.equals(dateIso)))
        .write(HabitLogsCompanion(count: Value(log.count - 1)));
  }

  // ── Streaks Calculation ────────────────────────────────────────────────────

  Future<int> computeStreak(Habit habit) async {
    final logs =
        await (_db.select(_db.habitLogs)
              ..where((l) => l.habitId.equals(habit.id))
              ..orderBy([(l) => OrderingTerm.desc(l.date)]))
            .get();

    if (logs.isEmpty) return 0;

    final logByDate = {for (final l in logs) l.date: l};
    var streak = 0;
    var checkDate = DateTime.now();

    // Reset checkDate to day only
    checkDate = DateTime(checkDate.year, checkDate.month, checkDate.day);

    // If today's target is not yet met, we check yesterday.
    // If yesterday is met, the streak is alive.
    // If not, and today is also not met, the streak is broken.
    final todayStr = _fmt(checkDate);
    final todayLog = logByDate[todayStr];
    final todayMet = todayLog != null && todayLog.count >= habit.targetPerDay;

    if (!todayMet) {
      // Check yesterday
      checkDate = checkDate.subtract(const Duration(days: 1));
      final yesterdayStr = _fmt(checkDate);
      final yesterdayLog = logByDate[yesterdayStr];
      final yesterdayMet =
          yesterdayLog != null && yesterdayLog.count >= habit.targetPerDay;
      if (!yesterdayMet) return 0;
    }

    // Now loop backwards counting consecutive met days
    while (true) {
      final dateStr = _fmt(checkDate);
      final log = logByDate[dateStr];
      if (log != null && log.count >= habit.targetPerDay) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return streak;
  }

  // ── Seeding ────────────────────────────────────────────────────────────────

  Future<void> seedDefaultHabitsIfNeeded() async {
    final existing = await _db.select(_db.habits).get();
    if (existing.isNotEmpty) return;

    final defaults = [
      HabitsCompanion.insert(
        name: 'Water',
        targetPerDay: const Value(8),
        reminderTimes: const Value(['09:00', '13:00', '17:00', '21:00']),
      ),
      HabitsCompanion.insert(
        name: 'Skincare AM',
        targetPerDay: const Value(1),
        reminderTimes: const Value(['09:00']),
      ),
      HabitsCompanion.insert(
        name: 'Skincare PM',
        targetPerDay: const Value(1),
        reminderTimes: const Value(['21:00']),
      ),
      HabitsCompanion.insert(
        name: 'Teeth',
        targetPerDay: const Value(2),
        reminderTimes: const Value(['09:00', '21:00']),
      ),
      HabitsCompanion.insert(
        name: 'Reading',
        targetPerDay: const Value(1),
        reminderTimes: const Value(['17:00']),
      ),
    ];

    for (final companion in defaults) {
      await _db.into(_db.habits).insert(companion);
    }

    await scheduleHabitReminders();
  }

  // ── Reminders ──────────────────────────────────────────────────────────────

  /// Schedules daily batched notifications for active habits.
  Future<void> scheduleHabitReminders() async {
    final ns = NotificationService();
    final activeHabits = await getActiveHabits();

    // Group active habits by reminder times
    final habitsByTime = <String, List<String>>{};
    for (final h in activeHabits) {
      final times = h.reminderTimes;
      if (times == null) continue;
      for (final t in times) {
        habitsByTime.putIfAbsent(t, () => []).add(h.name);
      }
    }

    // Cancel all current habit notifications (IDs 200–240)
    for (var id = 200; id <= 240; id++) {
      await ns.cancel(id);
    }

    // Schedule new batched notifications.
    // Map each unique reminder time to a distinct notification ID starting from 200.
    var id = 200;
    final now = DateTime.now();

    for (final entry in habitsByTime.entries) {
      if (id > 240) break; // stay inside namespace 200-240
      final timeStr = entry.key; // e.g. "09:00"
      final habitNames = entry.value;

      final parts = timeStr.split(':');
      if (parts.length != 2) continue;
      final hour = int.tryParse(parts[0]);
      final min = int.tryParse(parts[1]);
      if (hour == null || min == null) continue;

      var reminderDateTime = DateTime(now.year, now.month, now.day, hour, min);
      if (reminderDateTime.isBefore(now)) {
        reminderDateTime = reminderDateTime.add(const Duration(days: 1));
      }

      await ns.scheduleDailyBatch(
        id: id++,
        hour: hour,
        minute: min,
        title: 'Daily Habits Reminder',
        body: 'Time to check: ${habitNames.join(", ")}',
      );
    }
  }

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

final habitRepositoryProvider = Provider<HabitRepository>(
  (ref) => HabitRepository(ref.watch(appDatabaseProvider)),
);
