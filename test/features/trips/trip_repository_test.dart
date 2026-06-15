import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_planner/core/db/database.dart';
import 'package:personal_planner/core/db/repositories/day_repository.dart';
import 'package:personal_planner/features/trips/trip_repository.dart';
import 'package:drift/drift.dart' show Value;

AppDatabase _openDb() => AppDatabase(NativeDatabase.memory());

Future<TripRepository> _makeRepo(AppDatabase db) async {
  await DayRepository(db).seedDefaultTagsIfNeeded();
  return TripRepository(db);
}

void main() {
  late AppDatabase db;
  late TripRepository repo;

  setUp(() async {
    db = _openDb();
    repo = await _makeRepo(db);
  });

  tearDown(() => db.close());

  // ── Travel-tag write / reconcile ─────────────────────────────────

  test('finalizing a trip writes travel day_tags with source=trip', () async {
    await repo.createTrip(
      title: 'Vienna',
      status: 'final',
      startDate: '2026-07-01',
      endDate: '2026-07-03',
    );

    final dayRepo = DayRepository(db);
    for (final d in ['2026-07-01', '2026-07-02', '2026-07-03']) {
      final tags = await dayRepo.getTagsForDate(d);
      expect(tags.any((t) => t.name == 'travel'), isTrue, reason: 'date $d');
    }
    // Day outside range has no travel tag.
    final before = await dayRepo.getTagsForDate('2026-06-30');
    expect(before.any((t) => t.name == 'travel'), isFalse);
  });

  test(
    'cancel removes only source=trip tags, keeps manual travel tags',
    () async {
      final dayRepo = DayRepository(db);
      // Manually assign travel to 2026-07-02.
      final tags = await dayRepo.getAllTags();
      final travelTag = tags.firstWhere((t) => t.name == 'travel');
      await dayRepo.setTag('2026-07-02', travelTag.id, source: 'manual');

      final id = await repo.createTrip(
        title: 'Berlin',
        status: 'final',
        startDate: '2026-07-01',
        endDate: '2026-07-03',
      );

      await repo.cancelTrip(id);

      // 2026-07-01 and 2026-07-03 trip tags gone.
      final d1 = await dayRepo.getTagsForDate('2026-07-01');
      expect(d1.any((t) => t.name == 'travel'), isFalse);
      // 2026-07-02 manual tag survives.
      final d2 = await dayRepo.getTagsForDate('2026-07-02');
      expect(d2.any((t) => t.name == 'travel'), isTrue);
    },
  );

  test('date range change reconciles tags: removes stale, adds new', () async {
    final id = await repo.createTrip(
      title: 'Prague',
      status: 'final',
      startDate: '2026-08-01',
      endDate: '2026-08-03',
    );

    final trip = (await repo.getById(id))!;
    await repo.updateTrip(
      trip.copyWith(
        startDate: const Value('2026-08-05'),
        endDate: const Value('2026-08-07'),
      ),
    );

    final dayRepo = DayRepository(db);
    // Old range removed.
    for (final d in const ['2026-08-01', '2026-08-02', '2026-08-03']) {
      final tags = await dayRepo.getTagsForDate(d);
      expect(tags.any((t) => t.name == 'travel'), isFalse, reason: 'stale $d');
    }
    // New range added.
    for (final d in const ['2026-08-05', '2026-08-06', '2026-08-07']) {
      final tags = await dayRepo.getTagsForDate(d);
      expect(tags.any((t) => t.name == 'travel'), isTrue, reason: 'new $d');
    }
  });

  test('cancel keeps trip row but marks cancelled', () async {
    final id = await repo.createTrip(
      title: 'London',
      status: 'final',
      startDate: '2026-09-10',
      endDate: '2026-09-12',
    );
    await repo.cancelTrip(id);
    final trip = await repo.getById(id);
    expect(trip, isNotNull);
    expect(trip!.status, 'cancelled');
  });

  // ── Packing list ──────────────────────────────────────────────────

  test(
    'finalizing creates a packing list collection linked via packingCollectionId',
    () async {
      final id = await repo.createTrip(
        title: 'Tokyo',
        status: 'final',
        startDate: '2026-10-01',
        endDate: '2026-10-10',
      );
      final trip = await repo.getById(id);
      expect(trip!.packingCollectionId, isNotNull);

      final col = await (db.select(
        db.collections,
      )..where((c) => c.id.equals(trip.packingCollectionId!))).getSingle();
      expect(col.template, 'simple');
      expect(col.name, contains('Tokyo'));
    },
  );

  test('re-finalizing does NOT create a second packing list', () async {
    final id = await repo.createTrip(
      title: 'Madrid',
      status: 'final',
      startDate: '2026-11-01',
      endDate: '2026-11-05',
    );
    final trip1 = await repo.getById(id);
    final packingId1 = trip1!.packingCollectionId;

    await repo.updateTrip(trip1.copyWith(description: const Value('Updated')));
    final trip2 = await repo.getById(id);
    expect(trip2!.packingCollectionId, packingId1);
  });

  // ── Budget transaction ────────────────────────────────────────────

  test(
    'budget cents creates a planned transaction linked to the trip',
    () async {
      final id = await repo.createTrip(
        title: 'Paris',
        status: 'final',
        startDate: '2026-12-20',
        endDate: '2026-12-27',
        budgetCents: 150000,
      );
      final txns = await (db.select(
        db.transactions,
      )..where((t) => t.tripId.equals(id))).get();
      expect(txns.length, 1);
      expect(txns.first.amountCents, 150000);
      expect(txns.first.status, 'planned');
      expect(txns.first.direction, 'out');
    },
  );

  test('updating budget updates the transaction, does not duplicate', () async {
    final id = await repo.createTrip(
      title: 'Rome',
      status: 'final',
      startDate: '2027-01-10',
      endDate: '2027-01-14',
      budgetCents: 80000,
    );
    final trip = (await repo.getById(id))!;
    await repo.updateTrip(trip.copyWith(budgetCents: const Value(90000)));

    final txns = await (db.select(
      db.transactions,
    )..where((t) => t.tripId.equals(id))).get();
    expect(txns.length, 1);
    expect(txns.first.amountCents, 90000);
  });

  // ── Probable trip ─────────────────────────────────────────────────

  test('probable trip does not write travel tags', () async {
    await repo.createTrip(
      title: 'Maybe NYC',
      status: 'probable',
      startDate: '2027-03-01',
      endDate: '2027-03-07',
    );
    final dayRepo = DayRepository(db);
    final tags = await dayRepo.getTagsForDate('2027-03-01');
    expect(tags.any((t) => t.name == 'travel'), isFalse);
  });

  test('promoting probable to final writes travel tags', () async {
    final id = await repo.createTrip(
      title: 'Lisbon',
      status: 'probable',
      startDate: '2027-04-01',
      endDate: '2027-04-04',
    );
    await repo.finalizeTrip(id);
    final dayRepo = DayRepository(db);
    for (final d in const [
      '2027-04-01',
      '2027-04-02',
      '2027-04-03',
      '2027-04-04',
    ]) {
      final tags = await dayRepo.getTagsForDate(d);
      expect(tags.any((t) => t.name == 'travel'), isTrue, reason: d);
    }
  });
}
