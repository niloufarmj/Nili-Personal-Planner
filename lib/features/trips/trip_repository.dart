import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';

/// CRUD + status-flow for trips.
///
/// Status transitions: probable → final → done (or cancelled at any point).
/// On final: writes 'travel' day_tags (source='trip') and creates a packing list.
/// On date/status change when final: reconciles tags.
/// On cancel: removes source='trip' tags but keeps the trip row.
class TripRepository {
  TripRepository(this._db);

  final AppDatabase _db;

  // ── Queries ──────────────────────────────────────────────────────

  Stream<List<Trip>> watchAll() =>
      (_db.select(_db.trips)..orderBy([
            (t) =>
                OrderingTerm(expression: t.startDate, mode: OrderingMode.asc),
          ]))
          .watch();

  Stream<List<Trip>> watchByStatus(String status) =>
      (_db.select(_db.trips)
            ..where((t) => t.status.equals(status))
            ..orderBy([
              (t) =>
                  OrderingTerm(expression: t.startDate, mode: OrderingMode.asc),
            ]))
          .watch();

  Future<List<Trip>> getByStatus(String status) =>
      (_db.select(_db.trips)..where((t) => t.status.equals(status))).get();

  Future<Trip?> getById(int id) async {
    final rows = await (_db.select(
      _db.trips,
    )..where((t) => t.id.equals(id))).get();
    return rows.isEmpty ? null : rows.first;
  }

  // ── Create ───────────────────────────────────────────────────────

  Future<int> createTrip({
    required String title,
    required String status,
    String? startDate,
    String? endDate,
    String? location,
    String? description,
    List<String>? links,
    int? budgetCents,
  }) async {
    final id = await _db
        .into(_db.trips)
        .insert(
          TripsCompanion.insert(
            title: title,
            status: status,
            startDate: Value(startDate),
            endDate: Value(endDate),
            location: Value(location),
            description: Value(description),
            links: Value(links),
            budgetCents: Value(budgetCents),
          ),
        );

    if (status == 'final' && startDate != null && endDate != null) {
      await _applyTravelTags(startDate, endDate);
      await _ensurePackingList(id, title);
      if (budgetCents != null) {
        final trip = await getById(id);
        if (trip != null) await _upsertBudgetTransaction(trip);
      }
    }
    return id;
  }

  // ── Update ───────────────────────────────────────────────────────

  Future<void> updateTrip(Trip updated) async {
    final old = await getById(updated.id);
    await _db.update(_db.trips).replace(updated);

    final nowFinal = updated.status == 'final';
    final wasFinal = old?.status == 'final';
    final dateChanged =
        old?.startDate != updated.startDate || old?.endDate != updated.endDate;

    if (nowFinal && updated.startDate != null && updated.endDate != null) {
      if (!wasFinal || dateChanged) {
        // Remove stale trip tags from old range if dates changed.
        if (wasFinal &&
            dateChanged &&
            old?.startDate != null &&
            old?.endDate != null) {
          await _removeTripTags(
            _parseDate(old!.startDate!),
            _parseDate(old.endDate!),
          );
        }
        await _applyTravelTags(updated.startDate!, updated.endDate!);
      }
      await _ensurePackingList(updated.id, updated.title);
    } else if (wasFinal && !nowFinal) {
      if (old?.startDate != null && old?.endDate != null) {
        await _removeTripTags(
          _parseDate(old!.startDate!),
          _parseDate(old.endDate!),
        );
      }
    }

    if (updated.budgetCents != null) {
      await _upsertBudgetTransaction(updated);
    } else if (old?.budgetCents != null && updated.budgetCents == null) {
      await _deleteBudgetTransaction(updated.id);
    }
  }

  Future<void> finalizeTrip(int id) async {
    final trip = await getById(id);
    if (trip == null) return;
    await updateTrip(trip.copyWith(status: 'final'));
  }

  Future<void> markDone(int id) async {
    final trip = await getById(id);
    if (trip == null) return;
    await _db.update(_db.trips).replace(trip.copyWith(status: 'done'));
  }

  Future<void> cancelTrip(int id) async {
    final trip = await getById(id);
    if (trip == null) return;
    if (trip.status == 'final' &&
        trip.startDate != null &&
        trip.endDate != null) {
      await _removeTripTags(
        _parseDate(trip.startDate!),
        _parseDate(trip.endDate!),
      );
    }
    await _db.update(_db.trips).replace(trip.copyWith(status: 'cancelled'));
  }

  Future<void> deleteTrip(int id) async {
    await cancelTrip(id);
    await (_db.delete(_db.trips)..where((t) => t.id.equals(id))).go();
  }

  // ── Internals ────────────────────────────────────────────────────

  Future<void> _applyTravelTags(String startDate, String endDate) async {
    final tags = await (_db.select(
      _db.tags,
    )..where((t) => t.name.equals('travel'))).get();
    if (tags.isEmpty) return;
    final tagId = tags.first.id;
    var d = _dayOnly(_parseDate(startDate));
    final end = _dayOnly(_parseDate(endDate));
    while (!d.isAfter(end)) {
      // Use insertOrIgnore so existing manual travel tags are never overwritten.
      await _db
          .into(_db.dayTags)
          .insert(
            DayTagsCompanion.insert(
              date: _fmt(d),
              tagId: tagId,
              source: const Value('trip'),
            ),
            mode: InsertMode.insertOrIgnore,
          );
      d = d.add(const Duration(days: 1));
    }
  }

  Future<void> _removeTripTags(DateTime start, DateTime end) async {
    final tags = await (_db.select(
      _db.tags,
    )..where((t) => t.name.equals('travel'))).get();
    if (tags.isEmpty) return;
    final tagId = tags.first.id;
    var d = _dayOnly(start);
    while (!d.isAfter(_dayOnly(end))) {
      await (_db.delete(_db.dayTags)..where(
            (dt) =>
                dt.date.equals(_fmt(d)) &
                dt.tagId.equals(tagId) &
                dt.source.equals('trip'),
          ))
          .go();
      d = d.add(const Duration(days: 1));
    }
  }

  Future<void> _ensurePackingList(int tripId, String tripTitle) async {
    final trip = await getById(tripId);
    if (trip == null || trip.packingCollectionId != null) return;

    final name = tripTitle.isNotEmpty ? 'Packing — $tripTitle' : 'Packing list';
    final colId = await _db
        .into(_db.collections)
        .insert(CollectionsCompanion.insert(name: name, template: 'simple'));
    await (_db.update(_db.trips)..where((t) => t.id.equals(tripId))).write(
      TripsCompanion(packingCollectionId: Value(colId)),
    );
  }

  Future<void> _upsertBudgetTransaction(Trip trip) async {
    if (trip.budgetCents == null) return;
    final existing = await (_db.select(
      _db.transactions,
    )..where((t) => t.tripId.equals(trip.id))).get();
    final date = trip.startDate ?? _fmt(DateTime.now());
    if (existing.isEmpty) {
      await _db
          .into(_db.transactions)
          .insert(
            TransactionsCompanion.insert(
              date: date,
              amountCents: trip.budgetCents!,
              direction: 'out',
              status: 'planned',
              category: 'travel',
              tripId: Value(trip.id),
            ),
          );
    } else {
      await (_db.update(
        _db.transactions,
      )..where((t) => t.tripId.equals(trip.id))).write(
        TransactionsCompanion(
          amountCents: Value(trip.budgetCents!),
          date: Value(date),
        ),
      );
    }
  }

  Future<void> _deleteBudgetTransaction(int tripId) async {
    await (_db.delete(
      _db.transactions,
    )..where((t) => t.tripId.equals(tripId))).go();
  }

  static DateTime _parseDate(String iso) {
    final p = iso.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

final tripRepositoryProvider = Provider<TripRepository>(
  (ref) => TripRepository(ref.watch(appDatabaseProvider)),
);
