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
    String? coverImage,
  }) => _db
      .into(_db.collections)
      .insert(
        CollectionsCompanion.insert(
          name: name,
          template: template,
          parentId: Value(parentId),
          icon: Value(icon),
          sortOrder: Value(sortOrder),
          coverImage: Value(coverImage),
        ),
      );

  Future<void> update(Collection collection) =>
      _db.update(_db.collections).replace(collection);

  Future<void> rename(int id, String newName) =>
      (_db.update(_db.collections)..where((c) => c.id.equals(id))).write(
        CollectionsCompanion(name: Value(newName)),
      );

  Future<void> setCoverImage(int id, String? coverImage) =>
      (_db.update(_db.collections)..where((c) => c.id.equals(id))).write(
        CollectionsCompanion(coverImage: Value(coverImage)),
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
    await create(
      name: 'Chores',
      template: 'chore',
      coverImage: 'asset://assets/images/headers/header_chores.jpg',
    );
    await create(
      name: 'Shopping',
      template: 'shopping',
      coverImage: 'asset://assets/images/headers/header_groceries.jpg',
    );
    await create(
      name: 'Tech Wishlist',
      template: 'shopping',
      coverImage: 'asset://assets/images/headers/header_shopping.jpg',
    );
    await create(
      name: 'Life Upgrades',
      template: 'upgrade',
      coverImage: 'asset://assets/images/headers/header_chores.jpg',
    );
    await create(
      name: 'University',
      template: 'task',
      coverImage: 'asset://assets/images/headers/header_hobbies.jpg',
    );
    await create(
      name: 'Personal Projects',
      template: 'task',
      coverImage: 'asset://assets/images/headers/header_projects.jpg',
    );
    await create(
      name: 'Personal Growth',
      template: 'growth',
      coverImage: 'asset://assets/images/headers/header_hobbies.jpg',
    );
    await create(
      name: 'Hobbies',
      template: 'media',
      coverImage: 'asset://assets/images/headers/header_hobbies.jpg',
    );
    await create(
      name: 'Probable Plans',
      template: 'probable',
      coverImage: 'asset://assets/images/headers/header_projects.jpg',
    );

    // Job Hunt parent with Germany/Netherlands/Spain/Australia children
    final jobHuntId = await create(
      name: 'Job Hunt',
      template: 'job',
      coverImage: 'asset://assets/images/headers/header_job.jpg',
    );
    await create(
      name: 'Germany',
      template: 'job',
      parentId: jobHuntId,
      coverImage: 'asset://assets/images/headers/header_job.jpg',
    );
    await create(
      name: 'Netherlands',
      template: 'job',
      parentId: jobHuntId,
      coverImage: 'asset://assets/images/headers/header_job.jpg',
    );
    await create(
      name: 'Spain',
      template: 'job',
      parentId: jobHuntId,
      coverImage: 'asset://assets/images/headers/header_job.jpg',
    );
    await create(
      name: 'Australia',
      template: 'job',
      parentId: jobHuntId,
      coverImage: 'asset://assets/images/headers/header_job.jpg',
    );
  }

  /// Merges duplicate Job Hunt collections (e.g. "Germany" vs "Job Hunt — Germany").
  Future<void> deduplicateJobHuntCollections() async {
    final jobCols = await (_db.select(_db.collections)
          ..where((c) => c.template.equals('job') | c.name.like('%Job Hunt%')))
        .get();

    if (jobCols.isEmpty) return;

    final Map<String, List<Collection>> groups = {};
    for (final col in jobCols) {
      final norm = col.name
          .replaceAll('Job Hunt', '')
          .replaceAll('—', '')
          .replaceAll('-', '')
          .trim()
          .toLowerCase();
      if (norm.isEmpty) continue;
      groups.putIfAbsent(norm, () => []).add(col);
    }

    for (final entry in groups.entries) {
      final list = entry.value;
      if (list.length <= 1) continue;

      Collection primary = list.first;
      int maxItems = -1;
      for (final col in list) {
        final items = await (_db.select(_db.items)
              ..where((i) => i.collectionId.equals(col.id)))
            .get();
        if (items.length > maxItems) {
          maxItems = items.length;
          primary = col;
        }
      }

      final duplicates = list.where((c) => c.id != primary.id).toList();
      final primaryItems = await (_db.select(_db.items)
            ..where((i) => i.collectionId.equals(primary.id)))
          .get();
      final existingTitles = primaryItems.map((i) => i.title.toLowerCase()).toSet();

      for (final dup in duplicates) {
        final dupItems = await (_db.select(_db.items)
              ..where((i) => i.collectionId.equals(dup.id)))
            .get();
        for (final item in dupItems) {
          if (existingTitles.contains(item.title.toLowerCase())) {
            await (_db.delete(_db.items)..where((i) => i.id.equals(item.id))).go();
          } else {
            await (_db.update(_db.items)..where((i) => i.id.equals(item.id))).write(
              ItemsCompanion(collectionId: Value(primary.id)),
            );
            existingTitles.add(item.title.toLowerCase());
          }
        }
        await (_db.delete(_db.collections)..where((c) => c.id.equals(dup.id))).go();
      }
    }
  }
}

// ── Riverpod provider ──────────────────────────────────────────────────────────

final collectionRepositoryProvider = Provider<CollectionRepository>(
  (ref) => CollectionRepository(ref.watch(appDatabaseProvider)),
);
