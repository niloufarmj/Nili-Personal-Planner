import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';

/// Manages partner-owned tags and events (owner='partner').
class PartnerRepository {
  PartnerRepository(this._db);

  final AppDatabase _db;

  // ── Partner tags ─────────────────────────────────────────────────

  Stream<List<Tag>> watchPartnerTags() =>
      (_db.select(_db.tags)..where((t) => t.owner.equals('partner'))).watch();

  Future<int> createPartnerTag({
    required String name,
    required String color,
    String kind = 'partner',
  }) => _db
      .into(_db.tags)
      .insert(
        TagsCompanion.insert(
          name: name,
          color: color,
          kind: kind,
          owner: const Value('partner'),
        ),
      );

  Future<void> deletePartnerTag(int tagId) async {
    // Remove all day assignments for this tag first.
    await (_db.delete(_db.dayTags)..where((dt) => dt.tagId.equals(tagId))).go();
    await (_db.delete(_db.tags)..where((t) => t.id.equals(tagId))).go();
  }

  // ── Partner day assignments ───────────────────────────────────────

  Future<void> setPartnerTagForDate(String date, int tagId) => _db
      .into(_db.dayTags)
      .insertOnConflictUpdate(
        DayTagsCompanion.insert(
          date: date,
          tagId: tagId,
          source: const Value('manual'),
        ),
      );

  Future<void> removePartnerTagForDate(String date, int tagId) => (_db.delete(
    _db.dayTags,
  )..where((dt) => dt.date.equals(date) & dt.tagId.equals(tagId))).go();

  // ── Partner events ────────────────────────────────────────────────

  Stream<List<Event>> watchPartnerEvents() =>
      (_db.select(_db.events)..where((e) => e.owner.equals('partner'))).watch();

  Future<int> createPartnerEvent({
    required String title,
    required String date,
    String? startTime,
    String? endTime,
    String category = 'partner',
    String? rrule,
    String? notes,
  }) => _db
      .into(_db.events)
      .insert(
        EventsCompanion.insert(
          title: title,
          date: date,
          startTime: Value(startTime),
          endTime: Value(endTime),
          category: category,
          rrule: Value(rrule),
          notes: Value(notes),
          owner: const Value('partner'),
        ),
      );

  Future<void> updatePartnerEvent(Event event) =>
      _db.update(_db.events).replace(event);

  Future<void> deletePartnerEvent(int id) =>
      (_db.delete(_db.events)..where((e) => e.id.equals(id))).go();

  // ── Isolation guard ───────────────────────────────────────────────

  /// All calendar queries for 'me' exclude partner rows — this just surfaces
  /// partner data for the partner management screen.
  Future<List<Event>> getPartnerEventsForDate(String date) => (_db.select(
    _db.events,
  )..where((e) => e.owner.equals('partner') & e.date.equals(date))).get();
}

final partnerRepositoryProvider = Provider<PartnerRepository>(
  (ref) => PartnerRepository(ref.watch(appDatabaseProvider)),
);
