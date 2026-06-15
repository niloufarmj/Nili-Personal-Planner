import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';

// ── WorkoutPlanRepository ─────────────────────────────────────────────────────

class WorkoutPlanRepository {
  const WorkoutPlanRepository(this._db);
  final AppDatabase _db;

  Stream<List<WorkoutPlan>> watchAll() => _db.select(_db.workoutPlans).watch();

  Future<WorkoutPlan> get(int id) =>
      (_db.select(_db.workoutPlans)..where((p) => p.id.equals(id))).getSingle();

  Future<int> create({required String name, String content = ''}) => _db
      .into(_db.workoutPlans)
      .insert(WorkoutPlansCompanion.insert(name: name, content: content));

  Future<void> update(WorkoutPlan plan) =>
      _db.update(_db.workoutPlans).replace(plan);

  Future<void> delete(int id) =>
      (_db.delete(_db.workoutPlans)..where((p) => p.id.equals(id))).go();

  /// Seeds plans A / B / C (empty content) once — idempotent.
  Future<void> seedDefaultPlansIfNeeded() async {
    final existing = await _db.select(_db.workoutPlans).get();
    if (existing.isNotEmpty) return;
    for (final name in ['A', 'B', 'C']) {
      await _db
          .into(_db.workoutPlans)
          .insert(WorkoutPlansCompanion.insert(name: name, content: ''));
    }
  }
}

// ── GymRepository ─────────────────────────────────────────────────────────────

class GymRepository {
  const GymRepository(this._db);
  final AppDatabase _db;

  // ── Queries ───────────────────────────────────────────────────────

  Stream<List<GymSession>> watchUpcoming() {
    final todayStr = _fmtDate(DateTime.now());
    return (_db.select(_db.gymSessions)
          ..where(
            (s) =>
                s.status.equals('planned') &
                s.date.isBiggerOrEqualValue(todayStr),
          )
          ..orderBy([(s) => OrderingTerm.asc(s.date)]))
        .watch();
  }

  Stream<List<GymSession>> watchHistory() =>
      (_db.select(_db.gymSessions)
            ..where((s) => s.status.isIn(['done', 'missed']))
            ..orderBy([(s) => OrderingTerm.desc(s.date)]))
          .watch();

  Future<GymSession?> sessionForDate(String date) => (_db.select(
    _db.gymSessions,
  )..where((s) => s.date.equals(date))).getSingleOrNull();

  // ── Mutations ─────────────────────────────────────────────────────

  /// Creates or replaces a 'planned' session for the given date.
  /// Does not overwrite a 'done' session.
  Future<void> planSession({required String date, required int planId}) async {
    final existing = await sessionForDate(date);
    if (existing != null && existing.status == 'done') return;
    if (existing != null) {
      await (_db.update(
        _db.gymSessions,
      )..where((s) => s.id.equals(existing.id))).write(
        GymSessionsCompanion(
          planId: Value(planId),
          status: const Value('planned'),
        ),
      );
    } else {
      await _db
          .into(_db.gymSessions)
          .insert(
            GymSessionsCompanion.insert(
              date: date,
              planId: Value(planId),
              status: 'planned',
            ),
          );
    }
  }

  /// Marks a session as done. Creates one if none exists for the date.
  Future<void> logDone({
    required String date,
    int? planId,
    String? startTime,
    int? durationMin,
    String? notes,
  }) async {
    final existing = await sessionForDate(date);
    if (existing != null) {
      await (_db.update(
        _db.gymSessions,
      )..where((s) => s.id.equals(existing.id))).write(
        GymSessionsCompanion(
          status: const Value('done'),
          planId: planId != null ? Value(planId) : Value(existing.planId),
          startTime: startTime != null
              ? Value(startTime)
              : Value(existing.startTime),
          durationMin: durationMin != null
              ? Value(durationMin)
              : Value(existing.durationMin),
          notes: notes != null ? Value(notes) : Value(existing.notes),
        ),
      );
    } else {
      await _db
          .into(_db.gymSessions)
          .insert(
            GymSessionsCompanion.insert(
              date: date,
              planId: Value(planId),
              status: 'done',
              startTime: Value(startTime),
              durationMin: Value(durationMin),
              notes: Value(notes),
            ),
          );
    }
  }

  /// Daily maintenance: mark all past 'planned' sessions as 'missed'.
  /// Safe to call on every app open — only touches sessions before today.
  Future<int> markMissedSessions() async {
    final todayStr = _fmtDate(DateTime.now());
    return (_db.update(_db.gymSessions)..where(
          (s) =>
              s.status.equals('planned') & s.date.isSmallerThanValue(todayStr),
        ))
        .write(const GymSessionsCompanion(status: Value('missed')));
  }

  /// Number of 'done' sessions in the ISO week containing [weekStart].
  Future<int> doneCountForWeek(DateTime weekStart) async {
    final start = _fmtDate(_weekMonday(weekStart));
    final end = _fmtDate(_weekMonday(weekStart).add(const Duration(days: 6)));
    final rows =
        await (_db.select(_db.gymSessions)..where(
              (s) =>
                  s.status.equals('done') &
                  s.date.isBiggerOrEqualValue(start) &
                  s.date.isSmallerOrEqualValue(end),
            ))
            .get();
    return rows.length;
  }

  // ── Helpers ────────────────────────────────────────────────────────

  static String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static DateTime _weekMonday(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    final daysFromMonday = (day.weekday - 1) % 7;
    return day.subtract(Duration(days: daysFromMonday));
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final workoutPlanRepositoryProvider = Provider<WorkoutPlanRepository>(
  (ref) => WorkoutPlanRepository(ref.watch(appDatabaseProvider)),
);

final gymRepositoryProvider = Provider<GymRepository>(
  (ref) => GymRepository(ref.watch(appDatabaseProvider)),
);
