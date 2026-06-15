import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_planner/core/db/database.dart';
import 'package:personal_planner/features/gym/gym_repository.dart';

AppDatabase _openTestDb() => AppDatabase(NativeDatabase.memory());

void main() {
  late AppDatabase db;
  late WorkoutPlanRepository planRepo;
  late GymRepository gymRepo;

  setUp(() {
    db = _openTestDb();
    planRepo = WorkoutPlanRepository(db);
    gymRepo = GymRepository(db);
  });
  tearDown(() => db.close());

  // ── WorkoutPlanRepository ─────────────────────────────────────────────

  group('WorkoutPlanRepository', () {
    test('seed creates exactly A, B, C plans', () async {
      await planRepo.seedDefaultPlansIfNeeded();
      final plans = await db.select(db.workoutPlans).get();
      expect(plans.length, 3);
      expect(plans.map((p) => p.name), containsAll(['A', 'B', 'C']));
      expect(plans.every((p) => p.content == ''), isTrue);
    });

    test('seed is idempotent', () async {
      await planRepo.seedDefaultPlansIfNeeded();
      await planRepo.seedDefaultPlansIfNeeded();
      final plans = await db.select(db.workoutPlans).get();
      expect(plans.length, 3);
    });

    test('CRUD: create, get, update, delete', () async {
      final id = await planRepo.create(name: 'Test', content: '## Test');
      final plan = await planRepo.get(id);
      expect(plan.name, 'Test');
      expect(plan.content, '## Test');

      final updated = plan.copyWith(content: '## Updated');
      await planRepo.update(updated);
      final after = await planRepo.get(id);
      expect(after.content, '## Updated');

      await planRepo.delete(id);
      final count = await db.select(db.workoutPlans).get();
      expect(count.where((p) => p.id == id), isEmpty);
    });
  });

  // ── GymRepository: auto-missed ─────────────────────────────────────

  group('GymRepository.markMissedSessions', () {
    test('past planned session is marked missed', () async {
      final yesterday = _dateOffset(-1);
      await db
          .into(db.gymSessions)
          .insert(
            GymSessionsCompanion.insert(date: yesterday, status: 'planned'),
          );

      await gymRepo.markMissedSessions();

      final rows = await db.select(db.gymSessions).get();
      expect(rows.single.status, 'missed');
    });

    test("today's planned session is not touched", () async {
      final today = _today();
      await db
          .into(db.gymSessions)
          .insert(GymSessionsCompanion.insert(date: today, status: 'planned'));

      await gymRepo.markMissedSessions();

      final rows = await db.select(db.gymSessions).get();
      expect(rows.single.status, 'planned');
    });

    test('already-done sessions are not changed by markMissed', () async {
      final yesterday = _dateOffset(-1);
      await db
          .into(db.gymSessions)
          .insert(GymSessionsCompanion.insert(date: yesterday, status: 'done'));

      await gymRepo.markMissedSessions();

      final rows = await db.select(db.gymSessions).get();
      expect(rows.single.status, 'done');
    });

    test('marks multiple past planned sessions', () async {
      for (final offset in [-3, -2, -1]) {
        await db
            .into(db.gymSessions)
            .insert(
              GymSessionsCompanion.insert(
                date: _dateOffset(offset),
                status: 'planned',
              ),
            );
      }
      await gymRepo.markMissedSessions();
      final all = await db.select(db.gymSessions).get();
      expect(all.where((s) => s.status == 'missed').length, 3);
    });
  });

  // ── GymRepository: history ordering ──────────────────────────────────

  group('GymRepository.watchHistory', () {
    test('history is returned in descending date order', () async {
      for (final dateStr in ['2026-01-10', '2026-01-15', '2026-01-12']) {
        await db
            .into(db.gymSessions)
            .insert(GymSessionsCompanion.insert(date: dateStr, status: 'done'));
      }

      final history = await gymRepo.watchHistory().first;
      final dates = history.map((s) => s.date).toList();
      expect(dates, ['2026-01-15', '2026-01-12', '2026-01-10']);
    });

    test('missed sessions appear in history', () async {
      await db
          .into(db.gymSessions)
          .insert(
            GymSessionsCompanion.insert(date: '2026-01-10', status: 'missed'),
          );
      final history = await gymRepo.watchHistory().first;
      expect(history.length, 1);
      expect(history.first.status, 'missed');
    });

    test('planned sessions do not appear in history', () async {
      await db
          .into(db.gymSessions)
          .insert(
            GymSessionsCompanion.insert(date: _today(), status: 'planned'),
          );
      final history = await gymRepo.watchHistory().first;
      expect(history, isEmpty);
    });
  });

  // ── GymRepository: planSession / logDone ─────────────────────────────

  group('GymRepository.planSession', () {
    test('creates a planned session', () async {
      await planRepo.seedDefaultPlansIfNeeded();
      final plans = await db.select(db.workoutPlans).get();
      await gymRepo.planSession(date: _today(), planId: plans.first.id);

      final sessions = await db.select(db.gymSessions).get();
      expect(sessions.length, 1);
      expect(sessions.first.status, 'planned');
    });

    test('does not overwrite a done session', () async {
      await db
          .into(db.gymSessions)
          .insert(GymSessionsCompanion.insert(date: _today(), status: 'done'));
      await gymRepo.planSession(date: _today(), planId: 1);

      final sessions = await db.select(db.gymSessions).get();
      expect(sessions.single.status, 'done'); // still done
    });
  });

  group('GymRepository.logDone', () {
    test('marks existing planned session as done', () async {
      await db
          .into(db.gymSessions)
          .insert(
            GymSessionsCompanion.insert(date: _today(), status: 'planned'),
          );
      await gymRepo.logDone(date: _today(), durationMin: 45);

      final sessions = await db.select(db.gymSessions).get();
      expect(sessions.single.status, 'done');
      expect(sessions.single.durationMin, 45);
    });

    test('creates a done session if none exists', () async {
      await gymRepo.logDone(date: _today(), durationMin: 60, notes: 'great');

      final sessions = await db.select(db.gymSessions).get();
      expect(sessions.single.status, 'done');
      expect(sessions.single.notes, 'great');
    });
  });

  // ── GymRepository: week stat ──────────────────────────────────────────

  test('doneCountForWeek counts only done sessions in the week', () async {
    // Use a fixed Monday (2026-06-08 is a Monday)
    final monday = DateTime(2026, 6, 8);
    // Add sessions: 3 done in week, 1 done outside, 1 planned in week
    for (final date in ['2026-06-08', '2026-06-10', '2026-06-12']) {
      await db
          .into(db.gymSessions)
          .insert(GymSessionsCompanion.insert(date: date, status: 'done'));
    }
    await db
        .into(db.gymSessions)
        .insert(
          GymSessionsCompanion.insert(date: '2026-06-15', status: 'done'),
        );
    await db
        .into(db.gymSessions)
        .insert(
          GymSessionsCompanion.insert(date: '2026-06-09', status: 'planned'),
        );

    final count = await gymRepo.doneCountForWeek(monday);
    expect(count, 3);
  });
}

// ── Helpers ─────────────────────────────────────────────────────────────────

String _today() {
  final n = DateTime.now();
  return '${n.year.toString().padLeft(4, '0')}-'
      '${n.month.toString().padLeft(2, '0')}-'
      '${n.day.toString().padLeft(2, '0')}';
}

String _dateOffset(int days) {
  final d = DateTime.now().add(Duration(days: days));
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
