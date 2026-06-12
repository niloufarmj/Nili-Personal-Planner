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
}

// ── Riverpod provider ──────────────────────────────────────────────────────────

final collectionRepositoryProvider = Provider<CollectionRepository>(
  (ref) => CollectionRepository(ref.watch(appDatabaseProvider)),
);
