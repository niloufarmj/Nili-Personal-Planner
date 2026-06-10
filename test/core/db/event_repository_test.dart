import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_planner/core/db/database.dart';
import 'package:personal_planner/core/db/repositories/event_repository.dart';

AppDatabase _openDb() => AppDatabase(NativeDatabase.memory());

void main() {
  late AppDatabase db;
  late EventRepository repo;

  setUp(() {
    db = _openDb();
    repo = EventRepository(db);
  });
  tearDown(() => db.close());

  // ── One-off event ──────────────────────────────────────────────

  test('one-off event within window is returned', () async {
    await repo.createEvent(
      EventsCompanion.insert(
        title: 'Doctor',
        date: '2026-03-15',
        category: 'appointment',
      ),
    );
    final occs = await repo.expandOccurrences(
      DateTime(2026, 3, 1),
      DateTime(2026, 3, 31),
    );
    expect(occs.length, 1);
    expect(occs.first.event.title, 'Doctor');
    expect(occs.first.date, DateTime(2026, 3, 15));
  });

  test('one-off event outside window is excluded', () async {
    await repo.createEvent(
      EventsCompanion.insert(
        title: 'Old event',
        date: '2025-01-01',
        category: 'social',
      ),
    );
    final occs = await repo.expandOccurrences(
      DateTime(2026, 3, 1),
      DateTime(2026, 3, 31),
    );
    expect(occs, isEmpty);
  });

  // ── Weekly recurrence ──────────────────────────────────────────

  test('weekly repeat over 6 weeks returns 6 occurrences', () async {
    // Monday 2026-03-02
    await repo.createEvent(
      EventsCompanion.insert(
        title: 'Gym',
        date: '2026-03-02',
        category: 'social',
        rrule: const Value('FREQ=WEEKLY;BYDAY=MO'),
      ),
    );
    // Window: 6 weeks of Mondays starting 2026-03-02
    final occs = await repo.expandOccurrences(
      DateTime(2026, 3, 2),
      DateTime(2026, 4, 12),
    );
    expect(occs.length, 6);
    expect(occs.first.date, DateTime(2026, 3, 2));
    expect(occs.last.date, DateTime(2026, 4, 6));
  });

  // ── Repeat with end date ───────────────────────────────────────

  test('weekly repeat respects UNTIL end date', () async {
    await repo.createEvent(
      EventsCompanion.insert(
        title: 'Tuesday class',
        date: '2026-03-03',
        category: 'uni',
        rrule: const Value('FREQ=WEEKLY;BYDAY=TU;UNTIL=20260317T000000Z'),
      ),
    );
    final occs = await repo.expandOccurrences(
      DateTime(2026, 3, 1),
      DateTime(2026, 3, 31),
    );
    // Should get 2026-03-03, 2026-03-10, 2026-03-17 (UNTIL inclusive)
    expect(occs.length, greaterThanOrEqualTo(2));
    expect(occs.map((o) => o.date), isNot(contains(DateTime(2026, 3, 24))));
  });

  // ── Event with no rrule ────────────────────────────────────────

  test('event with null rrule is treated as one-off', () async {
    await repo.createEvent(
      EventsCompanion.insert(
        title: 'Birthday',
        date: '2026-06-10',
        category: 'social',
      ),
    );
    final occs = await repo.expandOccurrences(
      DateTime(2026, 6, 1),
      DateTime(2026, 6, 30),
    );
    expect(occs.length, 1);
    expect(occs.first.date, DateTime(2026, 6, 10));
  });

  // ── Multiple events ────────────────────────────────────────────

  test('results are sorted chronologically', () async {
    await repo.createEvent(
      EventsCompanion.insert(
        title: 'Late',
        date: '2026-03-20',
        category: 'other',
      ),
    );
    await repo.createEvent(
      EventsCompanion.insert(
        title: 'Early',
        date: '2026-03-05',
        category: 'other',
      ),
    );
    final occs = await repo.expandOccurrences(
      DateTime(2026, 3, 1),
      DateTime(2026, 3, 31),
    );
    expect(occs.length, 2);
    expect(occs.first.event.title, 'Early');
    expect(occs.last.event.title, 'Late');
  });

  // ── CRUD ───────────────────────────────────────────────────────

  test('deleteEvent removes the event', () async {
    final id = await repo.createEvent(
      EventsCompanion.insert(
        title: 'Temp',
        date: '2026-03-01',
        category: 'other',
      ),
    );
    await repo.deleteEvent(id);
    final event = await repo.getEvent(id);
    expect(event, isNull);
  });
}
