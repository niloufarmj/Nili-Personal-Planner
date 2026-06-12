import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_planner/core/conflicts/conflict_item.dart';
import 'package:personal_planner/core/conflicts/rules/travel_event_rule.dart';
import 'package:personal_planner/core/conflicts/rules/travel_gym_rule.dart';
import 'package:personal_planner/core/conflicts/rules/travel_meal_rule.dart';
import 'package:personal_planner/core/db/database.dart';
import 'package:personal_planner/core/db/repositories/day_repository.dart';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppDatabase _openDb() => AppDatabase(NativeDatabase.memory());

const _date = '2026-07-10';
final _dt = DateTime(2026, 7, 10);

Future<void> _addTravelTag(AppDatabase db) async {
  final dayRepo = DayRepository(db);
  final tags = await dayRepo.getAllTags();
  final travel = tags.firstWhere((t) => t.name == 'travel');
  await dayRepo.setTag(_date, travel.id);
}

Future<int> _addGymSession(AppDatabase db, {String status = 'planned'}) => db
    .into(db.gymSessions)
    .insert(GymSessionsCompanion.insert(date: _date, status: status));

Future<int> _addMealSlot(AppDatabase db, {String status = 'accepted'}) => db
    .into(db.mealSlots)
    .insert(
      MealSlotsCompanion.insert(date: _date, slot: 'dinner', status: status),
    );

void main() {
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = _openDb();
    await DayRepository(db).seedDefaultTagsIfNeeded();
  });

  tearDown(() => db.close());

  // ── R1: TravelGymRule ────────────────────────────────────────────────────────

  group('TravelGymRule', () {
    test('fires when travel tag + planned gym session on same day', () async {
      await _addTravelTag(db);
      await _addGymSession(db);
      final items = await const TravelGymRule().evaluate(db, _dt);
      expect(items.length, 1);
      expect(items.first.severity, ConflictSeverity.warning);
      expect(items.first.id, startsWith('R1:$_date'));
    });

    test('does not fire when no travel tag', () async {
      await _addGymSession(db);
      final items = await const TravelGymRule().evaluate(db, _dt);
      expect(items, isEmpty);
    });

    test('does not fire when no planned gym session', () async {
      await _addTravelTag(db);
      final items = await const TravelGymRule().evaluate(db, _dt);
      expect(items, isEmpty);
    });

    test('does not fire when session is done, not planned', () async {
      await _addTravelTag(db);
      await _addGymSession(db, status: 'done');
      final items = await const TravelGymRule().evaluate(db, _dt);
      expect(items, isEmpty);
    });

    test('skip action sets session status to missed', () async {
      await _addTravelTag(db);
      final sessionId = await _addGymSession(db);
      final items = await const TravelGymRule().evaluate(db, _dt);
      await items.first.actions.first.onTap(); // Skip session
      final updated = await (db.select(
        db.gymSessions,
      )..where((s) => s.id.equals(sessionId))).getSingle();
      expect(updated.status, 'missed');
    });

    test('move action relocates session to next non-travel day', () async {
      await _addTravelTag(db);
      final sessionId = await _addGymSession(db);
      final items = await const TravelGymRule().evaluate(db, _dt);
      await items.first.actions.last.onTap(); // Move to next free day
      final moved = await (db.select(
        db.gymSessions,
      )..where((s) => s.id.equals(sessionId))).getSingle();
      expect(moved.date, isNot(_date));
      expect(moved.date.compareTo(_date), greaterThan(0));
    });
  });

  // ── R2: TravelEventRule ──────────────────────────────────────────────────────

  group('TravelEventRule', () {
    test('fires when final trip overlaps a personal event', () async {
      // Create a final trip spanning the date.
      await db
          .into(db.trips)
          .insert(
            TripsCompanion.insert(
              title: 'Vienna',
              status: 'final',
              startDate: const Value('2026-07-08'),
              endDate: const Value('2026-07-12'),
            ),
          );
      // Add a 'me' event on that date.
      await db
          .into(db.events)
          .insert(
            EventsCompanion.insert(
              title: 'Doctor appointment',
              date: _date,
              owner: const Value('me'),
              category: 'appointment',
            ),
          );

      final items = await const TravelEventRule().evaluate(db, _dt);
      expect(items.length, 1);
      expect(items.first.severity, ConflictSeverity.info);
    });

    test('does not fire when no final trip', () async {
      await db
          .into(db.events)
          .insert(
            EventsCompanion.insert(
              title: 'Doctor',
              date: _date,
              owner: const Value('me'),
              category: 'appointment',
            ),
          );
      final items = await const TravelEventRule().evaluate(db, _dt);
      expect(items, isEmpty);
    });

    test('does not fire when trip is probable, not final', () async {
      await db
          .into(db.trips)
          .insert(
            TripsCompanion.insert(
              title: 'Maybe trip',
              status: 'probable',
              startDate: const Value('2026-07-08'),
              endDate: const Value('2026-07-12'),
            ),
          );
      await db
          .into(db.events)
          .insert(
            EventsCompanion.insert(
              title: 'Event',
              date: _date,
              owner: const Value('me'),
              category: 'personal',
            ),
          );
      final items = await const TravelEventRule().evaluate(db, _dt);
      expect(items, isEmpty);
    });
  });

  // ── R3: TravelMealRule ───────────────────────────────────────────────────────

  group('TravelMealRule', () {
    test('fires when travel tag + accepted meal slot on same day', () async {
      await _addTravelTag(db);
      await _addMealSlot(db);
      final items = await const TravelMealRule().evaluate(db, _dt);
      expect(items.length, 1);
      expect(items.first.severity, ConflictSeverity.warning);
      expect(items.first.id, startsWith('R3:$_date'));
    });

    test('does not fire when no travel tag', () async {
      await _addMealSlot(db);
      final items = await const TravelMealRule().evaluate(db, _dt);
      expect(items, isEmpty);
    });

    test('does not fire when no accepted/suggested meal slots', () async {
      await _addTravelTag(db);
      final items = await const TravelMealRule().evaluate(db, _dt);
      expect(items, isEmpty);
    });

    test('clear action deletes the meal slot', () async {
      await _addTravelTag(db);
      await _addMealSlot(db);
      final items = await const TravelMealRule().evaluate(db, _dt);
      await items.first.actions.first.onTap();
      final remaining = await (db.select(
        db.mealSlots,
      )..where((s) => s.date.equals(_date))).get();
      expect(remaining, isEmpty);
    });
  });
}
