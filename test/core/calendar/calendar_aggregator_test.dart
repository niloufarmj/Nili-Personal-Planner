import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_planner/core/calendar/calendar_aggregator.dart';
import 'package:personal_planner/core/calendar/calendar_day_data.dart';
import 'package:personal_planner/core/db/database.dart';
import 'package:personal_planner/core/db/repositories/day_repository.dart';
import 'package:personal_planner/core/db/repositories/event_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:personal_planner/core/design/design.dart';

AppDatabase _makeDb() => AppDatabase(NativeDatabase.memory());

Future<Map<String, CalendarDayData>> _aggregate(
  AppDatabase db, {
  DateTime? start,
  DateTime? end,
  CalendarFilter filter = CalendarFilter.all,
}) {
  final repo = EventRepository(db);
  final agg = CalendarAggregator(db, repo);
  return agg.getDataForRange(
    start ?? DateTime(2025, 1, 1),
    end ?? DateTime(2025, 1, 31),
    filter: filter,
  );
}

void main() {
  group('CalendarAggregator', () {
    late AppDatabase db;

    setUp(() async {
      db = _makeDb();
      // Seed default tags (linz, salzburg, travel, gym, work, reza-day)
      await DayRepository(db).seedDefaultTagsIfNeeded();
    });

    tearDown(() => db.close());

    // ── Empty DB ─────────────────────────────────────────────────────────────

    test('empty DB returns clean CalendarDayData for every day in range',
        () async {
      final data = await _aggregate(
        db,
        start: DateTime(2025, 1, 1),
        end: DateTime(2025, 1, 3),
      );
      expect(data.length, 3);
      for (final d in data.values) {
        expect(d.isEmpty, isTrue);
      }
    });

    // ── Location overlay precedence ───────────────────────────────────────────

    test('travel overlay wins over linz/salzburg', () async {
      final dayRepo = DayRepository(db);
      // Tag Jan 5 with both linz and travel
      // Find linz and travel tag ids
      final allTags =
          await (db.select(db.tags)..where((t) => t.kind.equals('location')))
              .get();
      final linzTag = allTags.firstWhere((t) => t.name == 'linz');
      final travelTag = allTags.firstWhere((t) => t.name == 'travel');

      await dayRepo.setTag('2025-01-05', linzTag.id);
      await dayRepo.setTag('2025-01-05', travelTag.id);

      final data = await _aggregate(
        db,
        start: DateTime(2025, 1, 5),
        end: DateTime(2025, 1, 5),
      );
      final day = data['2025-01-05']!;
      // Travel's sage should win over linz butter
      expect(day.overlayColor, AppColors.travel);
    });

    test('linz overlay set when only linz tag present', () async {
      final dayRepo = DayRepository(db);
      final allTags =
          await (db.select(db.tags)..where((t) => t.name.equals('linz'))).get();
      await dayRepo.setTag('2025-01-10', allTags.first.id);

      final data = await _aggregate(
        db,
        start: DateTime(2025, 1, 10),
        end: DateTime(2025, 1, 10),
      );
      expect(data['2025-01-10']!.overlayColor, AppColors.linz);
    });

    // ── Multi-tag activity icons ───────────────────────────────────────────────

    test('activity tags produce icons', () async {
      final dayRepo = DayRepository(db);
      final gymTag = await (db.select(db.tags)
            ..where((t) => t.name.equals('gym')))
          .getSingle();
      await dayRepo.setTag('2025-01-15', gymTag.id);

      final data = await _aggregate(
        db,
        start: DateTime(2025, 1, 15),
        end: DateTime(2025, 1, 15),
      );
      expect(
        data['2025-01-15']!.activityIcons,
        contains(Icons.fitness_center),
      );
    });

    test('multi-tag day has both overlay and activity icons', () async {
      final dayRepo = DayRepository(db);
      final linzTag = await (db.select(db.tags)
            ..where((t) => t.name.equals('linz')))
          .getSingle();
      final gymTag = await (db.select(db.tags)
            ..where((t) => t.name.equals('gym')))
          .getSingle();
      await dayRepo.setTag('2025-01-20', linzTag.id);
      await dayRepo.setTag('2025-01-20', gymTag.id);

      final data = await _aggregate(
        db,
        start: DateTime(2025, 1, 20),
        end: DateTime(2025, 1, 20),
      );
      final day = data['2025-01-20']!;
      expect(day.overlayColor, isNotNull);
      expect(day.activityIcons, contains(Icons.fitness_center));
    });

    // ── Filter toggles ────────────────────────────────────────────────────────

    test('showLocation=false hides location overlay', () async {
      final dayRepo = DayRepository(db);
      final linzTag = await (db.select(db.tags)
            ..where((t) => t.name.equals('linz')))
          .getSingle();
      await dayRepo.setTag('2025-01-05', linzTag.id);

      final data = await _aggregate(
        db,
        start: DateTime(2025, 1, 5),
        end: DateTime(2025, 1, 5),
        filter: CalendarFilter.all.copyWith(showLocation: false),
      );
      expect(data['2025-01-05']!.overlayColor, isNull);
    });

    test('showGym=false hides gym activity icon', () async {
      final dayRepo = DayRepository(db);
      final gymTag = await (db.select(db.tags)
            ..where((t) => t.name.equals('gym')))
          .getSingle();
      await dayRepo.setTag('2025-01-15', gymTag.id);

      final data = await _aggregate(
        db,
        start: DateTime(2025, 1, 15),
        end: DateTime(2025, 1, 15),
        filter: CalendarFilter.all.copyWith(showGym: false),
      );
      expect(data['2025-01-15']!.activityIcons, isEmpty);
    });

    test('showPartner=false hides partner events', () async {
      final eventRepo = EventRepository(db);
      await eventRepo.createEvent(
        const EventsCompanion(
          title: Value('Partner dinner'),
          date: Value('2025-01-10'),
          category: Value('partner'),
          owner: Value('partner'),
        ),
      );

      final data = await _aggregate(
        db,
        start: DateTime(2025, 1, 10),
        end: DateTime(2025, 1, 10),
        filter: CalendarFilter.all.copyWith(showPartner: false),
      );
      expect(data['2025-01-10']!.partnerEvents, isEmpty);
    });

    // ── Events ────────────────────────────────────────────────────────────────

    test('events appear in the correct day bucket', () async {
      final eventRepo = EventRepository(db);
      await eventRepo.createEvent(
        const EventsCompanion(
          title: Value('Doctor'),
          date: Value('2025-01-12'),
          category: Value('appointment'),
          owner: Value('me'),
        ),
      );

      final data = await _aggregate(
        db,
        start: DateTime(2025, 1, 1),
        end: DateTime(2025, 1, 31),
      );
      expect(data['2025-01-12']!.eventOccurrences.length, 1);
      expect(data['2025-01-11']!.eventOccurrences, isEmpty);
    });

    // ── Trip bars ─────────────────────────────────────────────────────────────

    test('final trip spans all days in its range', () async {
      await db.into(db.trips).insert(
        const TripsCompanion(
          title: Value('Vienna trip'),
          status: Value('final'),
          startDate: Value('2025-01-08'),
          endDate: Value('2025-01-10'),
        ),
      );

      final data = await _aggregate(
        db,
        start: DateTime(2025, 1, 1),
        end: DateTime(2025, 1, 31),
      );
      expect(data['2025-01-07']!.tripBars, isEmpty);
      expect(data['2025-01-08']!.tripBars.length, 1);
      expect(data['2025-01-09']!.tripBars.length, 1);
      expect(data['2025-01-10']!.tripBars.length, 1);
      expect(data['2025-01-11']!.tripBars, isEmpty);
    });

    test('probable trip is not shown as bar', () async {
      await db.into(db.trips).insert(
        const TripsCompanion(
          title: Value('Maybe trip'),
          status: Value('probable'),
          startDate: Value('2025-01-08'),
          endDate: Value('2025-01-10'),
        ),
      );

      final data = await _aggregate(
        db,
        start: DateTime(2025, 1, 1),
        end: DateTime(2025, 1, 31),
      );
      expect(data['2025-01-08']!.tripBars, isEmpty);
    });

    // ── Reminders ─────────────────────────────────────────────────────────────

    test('active reminder appears in window days', () async {
      await db.into(db.reminders).insert(
        const RemindersCompanion(
          title: Value('Call dentist'),
          windowStart: Value('2025-01-14'),
          windowEnd: Value('2025-01-16'),
          status: Value('open'),
        ),
      );

      final data = await _aggregate(
        db,
        start: DateTime(2025, 1, 1),
        end: DateTime(2025, 1, 31),
      );
      expect(data['2025-01-13']!.activeReminders, isEmpty);
      expect(data['2025-01-14']!.activeReminders.length, 1);
      expect(data['2025-01-15']!.activeReminders.length, 1);
      expect(data['2025-01-16']!.activeReminders.length, 1);
      expect(data['2025-01-17']!.activeReminders, isEmpty);
    });

    test('dismissed reminder is not shown', () async {
      await db.into(db.reminders).insert(
        const RemindersCompanion(
          title: Value('Old reminder'),
          windowStart: Value('2025-01-14'),
          windowEnd: Value('2025-01-16'),
          status: Value('dismissed'),
        ),
      );

      final data = await _aggregate(
        db,
        start: DateTime(2025, 1, 1),
        end: DateTime(2025, 1, 31),
      );
      expect(data['2025-01-15']!.activeReminders, isEmpty);
    });
  });
}
