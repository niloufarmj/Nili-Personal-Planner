import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';

/// CRUD + reactive queries for the [Collections] table.
class CollectionRepository {
  const CollectionRepository(this._db);

  final AppDatabase _db;

  // ── Watch ────────────────────────────────────────────────────────

  /// Stream of non-archived collections, optionally filtered by [parentId].
  /// Pass `parentId: null` (default) for top-level collections.
  /// Pass a specific id to get children of that parent.
  Stream<List<Collection>> watchCollections({
    int? parentId,
    bool includeArchived = false,
  }) {
    final q = _db.select(_db.collections)
      ..orderBy([
        (c) => OrderingTerm.asc(c.sortOrder),
        (c) => OrderingTerm.asc(c.name),
      ]);
    return q.watch().map(
      (rows) => rows.where((c) {
        if (!includeArchived && c.archived) return false;
        if (parentId == null) {
          return c.parentId == null;
        }
        return c.parentId == parentId;
      }).toList(),
    );
  }

  /// Stream of ALL non-archived collections regardless of parent (for grid view).
  Stream<List<Collection>> watchAll({bool includeArchived = false}) {
    return (_db.select(_db.collections)..orderBy([
          (c) => OrderingTerm.asc(c.sortOrder),
          (c) => OrderingTerm.asc(c.name),
        ]))
        .watch()
        .map(
          (rows) =>
              includeArchived ? rows : rows.where((c) => !c.archived).toList(),
        );
  }

  // ── CRUD ─────────────────────────────────────────────────────────

  Future<Collection?> getById(int id) => (_db.select(
    _db.collections,
  )..where((c) => c.id.equals(id))).getSingleOrNull();

  Future<Collection?> getByTemplate(String template) => (_db.select(
    _db.collections,
  )..where((c) => c.template.equals(template))).getSingleOrNull();

  Future<int> create({
    required String name,
    required String template,
    int? parentId,
    String? icon,
    int? sortOrder,
  }) => _db
      .into(_db.collections)
      .insert(
        CollectionsCompanion.insert(
          name: name,
          template: template,
          parentId: Value(parentId),
          icon: Value(icon),
          sortOrder: Value(sortOrder),
        ),
      );

  Future<void> update(Collection collection) =>
      _db.update(_db.collections).replace(collection);

  Future<void> rename(int id, String newName) =>
      (_db.update(_db.collections)..where((c) => c.id.equals(id))).write(
        CollectionsCompanion(name: Value(newName)),
      );

  Future<void> archive(int id) =>
      (_db.update(_db.collections)..where((c) => c.id.equals(id))).write(
        const CollectionsCompanion(archived: Value(true)),
      );

  Future<void> unarchive(int id) =>
      (_db.update(_db.collections)..where((c) => c.id.equals(id))).write(
        const CollectionsCompanion(archived: Value(false)),
      );

  Future<int> delete(int id) =>
      (_db.delete(_db.collections)..where((c) => c.id.equals(id))).go();

  /// Seeds the default collections on first launch if none exist.
  Future<void> seedDefaultCollectionsIfNeeded() async {
    final existing = await _db.select(_db.collections).get();
    if (existing.isNotEmpty) return;

    // Seed top-level collections
    await create(name: 'Chores', template: 'chore');
    await create(name: 'Shopping', template: 'shopping');
    await create(name: 'Tech Wishlist', template: 'shopping');
    await create(name: 'Life Upgrades', template: 'upgrade');
    await create(name: 'University', template: 'task');
    await create(name: 'Personal Projects', template: 'task');
    await create(name: 'Personal Growth', template: 'growth');
    await create(name: 'Hobbies', template: 'media');
    await create(name: 'Probable Plans', template: 'probable');

    // Job Hunt parent with Germany/Netherlands/Spain/Australia children
    final jobHuntId = await create(name: 'Job Hunt', template: 'job');
    await create(name: 'Germany', template: 'job', parentId: jobHuntId);
    await create(name: 'Netherlands', template: 'job', parentId: jobHuntId);
    await create(name: 'Spain', template: 'job', parentId: jobHuntId);
    await create(name: 'Australia', template: 'job', parentId: jobHuntId);
  }
}

// ── Riverpod provider ──────────────────────────────────────────────────────────

final collectionRepositoryProvider = Provider<CollectionRepository>(
  (ref) => CollectionRepository(ref.watch(appDatabaseProvider)),
);
