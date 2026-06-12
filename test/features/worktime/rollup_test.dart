import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_planner/core/db/database.dart';
import 'package:personal_planner/features/worktime/repositories/worktime_repository.dart';
import 'package:personal_planner/features/worktime/services/rollup_service.dart';

AppDatabase _openDb() => AppDatabase(NativeDatabase.memory());

void main() {
  late AppDatabase db;
  late WorktimeRepository repo;

  setUp(() {
    db = _openDb();
    repo = WorktimeRepository(db);
  });

  tearDown(() => db.close());

  // ── Rollup math ───────────────────────────────────────────────────────────

  group('RollupService.compute', () {
    test('zero minutes → saved days is negative', () {
      final r = RollupService.compute(
        todayMinutes: 0,
        weekMinutes: 0,
        monthPerContext: {},
        baselineHoursPerWeek: 40,
      );
      expect(r.savedDays, isNegative);
      expect(r.savedDays, -5.0); // -(40*60) / (8*60)
    });

    test('exact baseline → 0 saved days', () {
      final r = RollupService.compute(
        todayMinutes: 480,
        weekMinutes: 40 * 60, // exactly 40 h
        monthPerContext: {},
        baselineHoursPerWeek: 40,
      );
      expect(r.savedDays, 0.0);
    });

    test('overtime → positive saved days', () {
      const extraMinutes = 8 * 60; // one full extra day
      final r = RollupService.compute(
        todayMinutes: 480,
        weekMinutes: 40 * 60 + extraMinutes,
        monthPerContext: {},
        baselineHoursPerWeek: 40,
      );
      expect(r.savedDays, closeTo(1.0, 0.001));
    });

    test('configurable baseline: 30 h/week', () {
      final r = RollupService.compute(
        todayMinutes: 360,
        weekMinutes: 30 * 60,
        monthPerContext: {},
        baselineHoursPerWeek: 30,
      );
      expect(r.savedDays, 0.0);
    });

    test('multiple contexts in month totals', () {
      final r = RollupService.compute(
        todayMinutes: 120,
        weekMinutes: 120,
        monthPerContext: {1: 480, 2: 300, 3: 120},
        baselineHoursPerWeek: 40,
      );
      expect(r.monthPerContext[1], 480);
      expect(r.monthPerContext[2], 300);
      expect(r.monthPerContext[3], 120);
    });

    test('formatMinutes produces correct string', () {
      expect(RollupService.formatMinutes(0), '0m');
      expect(RollupService.formatMinutes(45), '45m');
      expect(RollupService.formatMinutes(60), '1h');
      expect(RollupService.formatMinutes(90), '1h 30m');
      expect(RollupService.formatMinutes(480), '8h');
    });
  });

  // ── Repository rollups ────────────────────────────────────────────────────

  group('WorktimeRepository rollups', () {
    test('getTotalMinutesForDate sums entries on that date', () async {
      final ctxId = await repo.createContext('FreshFX');
      await repo.createEntry(
        TimeEntriesCompanion.insert(
          contextId: ctxId,
          date: '2026-06-11',
          minutes: 120,
        ),
      );
      await repo.createEntry(
        TimeEntriesCompanion.insert(
          contextId: ctxId,
          date: '2026-06-11',
          minutes: 60,
        ),
      );
      await repo.createEntry(
        TimeEntriesCompanion.insert(
          contextId: ctxId,
          date: '2026-06-12',
          minutes: 90,
        ),
      );

      expect(await repo.getTotalMinutesForDate('2026-06-11'), 180);
      expect(await repo.getTotalMinutesForDate('2026-06-12'), 90);
    });

    test('getTotalMinutesForWeek sums entries in Mon–Sun window', () async {
      final ctxId = await repo.createContext('Tutoring');
      // Week of Jun 9 (Mon) – Jun 15 (Sun)
      for (final day in ['2026-06-09', '2026-06-10', '2026-06-11']) {
        await repo.createEntry(
          TimeEntriesCompanion.insert(
            contextId: ctxId,
            date: day,
            minutes: 120,
          ),
        );
      }
      // Outside the window
      await repo.createEntry(
        TimeEntriesCompanion.insert(
          contextId: ctxId,
          date: '2026-06-16',
          minutes: 99,
        ),
      );

      final total = await repo.getTotalMinutesForWeek(
        DateTime(2026, 6, 9), // Monday
      );
      expect(total, 360); // 3 × 120
    });

    test('getMinutesPerContextForMonth groups by context', () async {
      final ctx1 = await repo.createContext('FreshFX');
      final ctx2 = await repo.createContext('Startup');

      await repo.createEntry(
        TimeEntriesCompanion.insert(
          contextId: ctx1,
          date: '2026-06-01',
          minutes: 300,
        ),
      );
      await repo.createEntry(
        TimeEntriesCompanion.insert(
          contextId: ctx2,
          date: '2026-06-05',
          minutes: 200,
        ),
      );
      await repo.createEntry(
        TimeEntriesCompanion.insert(
          contextId: ctx1,
          date: '2026-06-15',
          minutes: 100,
        ),
      );

      final result = await repo.getMinutesPerContextForMonth(2026, 6);
      expect(result[ctx1], 400);
      expect(result[ctx2], 200);
    });

    test('stopTimer uses injected clock to compute minutes', () async {
      final ctxId = await repo.createContext('Test');
      final fakeStart = DateTime(2026, 6, 11, 9, 0);
      final fakeNow = DateTime(2026, 6, 11, 10, 30); // 90 minutes later

      final injectedRepo = WorktimeRepository(db, clock: () => fakeNow);

      await injectedRepo.stopTimer(contextId: ctxId, startedAt: fakeStart);

      final entries = await repo.getEntriesForDate('2026-06-11');
      expect(entries.length, 1);
      expect(entries.first.minutes, 90);
    });

    test('baseline hours persisted and retrieved', () async {
      await repo.setBaselineHoursPerWeek(32);
      expect(await repo.getBaselineHoursPerWeek(), 32);
    });

    test('default baseline is 40 when not set', () async {
      expect(await repo.getBaselineHoursPerWeek(), 40);
    });
  });
}
