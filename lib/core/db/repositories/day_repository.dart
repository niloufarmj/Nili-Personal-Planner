import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database.dart';

/// Seed data written on first launch.
const _defaultTags = [
  (name: 'linz', color: '#F5C518', kind: 'location'),
  (name: 'salzburg', color: '#7C5CBF', kind: 'location'),
  (name: 'travel', color: '#3EBF6F', kind: 'location'),
  (name: 'gym', color: '#EF6C00', kind: 'activity'),
  (name: 'work', color: '#1565C0', kind: 'activity'),
  (name: 'reza-day', color: '#AB47BC', kind: 'special'),
];

/// Repository for day_tags and the tags catalogue.
class DayRepository {
  const DayRepository(this._db);

  final AppDatabase _db;

  // ── Seed ────────────────────────────────────────────────────────

  /// Inserts default tags if the tags table is empty.
  Future<void> seedDefaultTagsIfNeeded() async {
    final count = await _db.tags.count().getSingle();
    if (count > 0) return;
    for (final t in _defaultTags) {
      await _db
          .into(_db.tags)
          .insert(
            TagsCompanion.insert(name: t.name, color: t.color, kind: t.kind),
          );
    }
  }

  // ── Tags catalogue ───────────────────────────────────────────────

  Stream<List<Tag>> watchAllTags() => _db.select(_db.tags).watch();

  Future<List<Tag>> getAllTags() => _db.select(_db.tags).get();

  Future<Tag> getTag(int id) =>
      (_db.select(_db.tags)..where((t) => t.id.equals(id))).getSingle();

  Future<int> createTag({
    required String name,
    required String color,
    required String kind,
    String owner = 'me',
  }) => _db
      .into(_db.tags)
      .insert(
        TagsCompanion.insert(
          name: name,
          color: color,
          kind: kind,
          owner: Value(owner),
        ),
      );

  Future<void> updateTag(Tag tag) => _db.update(_db.tags).replace(tag);

  // ── Day tags ─────────────────────────────────────────────────────

  /// Reactive stream of tags assigned to dates in [start..end] (inclusive).
  Stream<Map<String, List<Tag>>> watchTagsForRange(
    DateTime start,
    DateTime end,
  ) {
    final startStr = _fmt(start);
    final endStr = _fmt(end);
    final tagQuery = _db.select(_db.tags);
    final dayTagQuery = _db.select(_db.dayTags)
      ..where((dt) => dt.date.isBetweenValues(startStr, endStr));

    return tagQuery.watch().asyncExpand((tags) {
      final tagMap = {for (final t in tags) t.id: t};
      return dayTagQuery.watch().map((dayTags) {
        final result = <String, List<Tag>>{};
        for (final dt in dayTags) {
          final tag = tagMap[dt.tagId];
          if (tag != null) {
            (result[dt.date] ??= []).add(tag);
          }
        }
        return result;
      });
    });
  }

  Future<List<Tag>> getTagsForDate(String date) async {
    final dayTags = await (_db.select(
      _db.dayTags,
    )..where((dt) => dt.date.equals(date))).get();
    if (dayTags.isEmpty) return [];
    final ids = dayTags.map((dt) => dt.tagId).toList();
    return (_db.select(_db.tags)..where((t) => t.id.isIn(ids))).get();
  }

  /// Assigns [tagId] to [date]. Idempotent — safe to call multiple times.
  Future<void> setTag(String date, int tagId, {String source = 'manual'}) => _db
      .into(_db.dayTags)
      .insertOnConflictUpdate(
        DayTagsCompanion.insert(
          date: date,
          tagId: tagId,
          source: Value(source),
        ),
      );

  /// Removes [tagId] from [date].
  Future<int> removeTag(String date, int tagId) => (_db.delete(
    _db.dayTags,
  )..where((dt) => dt.date.equals(date) & dt.tagId.equals(tagId))).go();

  /// Assigns a tag by name to a date range (used when a trip becomes 'final').
  Future<void> setTagByNameForRange(
    String tagName,
    DateTime start,
    DateTime end, {
    String source = 'trip',
  }) async {
    final tags = await (_db.select(
      _db.tags,
    )..where((t) => t.name.equals(tagName))).get();
    if (tags.isEmpty) return;
    final tagId = tags.first.id;
    var current = start;
    while (!current.isAfter(end)) {
      await setTag(_fmt(current), tagId, source: source);
      current = current.add(const Duration(days: 1));
    }
  }

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

// ── Riverpod providers ──────────────────────────────────────────────────────

final dayRepositoryProvider = Provider<DayRepository>(
  (ref) => DayRepository(ref.watch(appDatabaseProvider)),
);
