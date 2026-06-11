import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/db/database.dart';

enum ItemSort { priorityDueDateManual }

/// CRUD + reactive queries for [Items] and [Subtasks].
class ItemRepository {
  const ItemRepository(this._db);

  final AppDatabase _db;

  static final _dateFmt = DateFormat('yyyy-MM-dd');

  // ── Watch items ──────────────────────────────────────────────────

  /// Reactive stream of items in a collection, sorted priority → due_date → sort_order.
  /// Optional [statusFilter] restricts to a specific status value.
  Stream<List<Item>> watchItems(
    int collectionId, {
    String? statusFilter,
    bool includeArchived = false,
  }) {
    return (_db.select(_db.items)
          ..where((i) => i.collectionId.equals(collectionId))
          ..orderBy([
            (i) => OrderingTerm(
              expression: i.priority,
              mode: OrderingMode.asc,
              nulls: NullsOrder.last,
            ),
            (i) => OrderingTerm(
              expression: i.dueDate,
              mode: OrderingMode.asc,
              nulls: NullsOrder.last,
            ),
          ]))
        .watch()
        .map(
          (rows) => statusFilter == null
              ? rows
              : rows.where((i) => i.status == statusFilter).toList(),
        );
  }

  // ── CRUD ─────────────────────────────────────────────────────────

  Future<Item?> getById(int id) =>
      (_db.select(_db.items)..where((i) => i.id.equals(id))).getSingleOrNull();

  Future<int> createItem(ItemsCompanion companion) =>
      _db.into(_db.items).insert(companion);

  Future<void> updateItem(Item item) => _db.update(_db.items).replace(item);

  Future<int> deleteItem(int id) =>
      (_db.delete(_db.items)..where((i) => i.id.equals(id))).go();

  // ── Status toggle (tick / untick) ────────────────────────────────

  /// Marks an item done: sets status to [doneStatus] and records today as done_date.
  /// Clears done_date if status is already [doneStatus] (untick).
  Future<void> toggleItemStatus(
    int itemId, {
    required String doneStatus,
    required String openStatus,
  }) async {
    final item = await getById(itemId);
    if (item == null) return;

    final isDone = item.status == doneStatus;
    await (_db.update(_db.items)..where((i) => i.id.equals(itemId))).write(
      ItemsCompanion(
        status: Value(isDone ? openStatus : doneStatus),
        doneDate: Value(isDone ? null : _dateFmt.format(DateTime.now())),
      ),
    );
  }

  // ── Subtasks ─────────────────────────────────────────────────────

  Stream<List<Subtask>> watchSubtasks(int itemId) =>
      (_db.select(_db.subtasks)
            ..where((s) => s.itemId.equals(itemId))
            ..orderBy([(s) => OrderingTerm.asc(s.sortOrder)]))
          .watch();

  Future<List<Subtask>> getSubtasks(int itemId) =>
      (_db.select(_db.subtasks)
            ..where((s) => s.itemId.equals(itemId))
            ..orderBy([(s) => OrderingTerm.asc(s.sortOrder)]))
          .get();

  Future<int> createSubtask({
    required int itemId,
    required String title,
    int? sortOrder,
  }) => _db
      .into(_db.subtasks)
      .insert(
        SubtasksCompanion.insert(
          itemId: itemId,
          title: title,
          sortOrder: Value(sortOrder),
        ),
      );

  Future<void> toggleSubtask(int subtaskId) async {
    final sub = await (_db.select(
      _db.subtasks,
    )..where((s) => s.id.equals(subtaskId))).getSingleOrNull();
    if (sub == null) return;
    final next = sub.status == 'done' ? 'open' : 'done';
    await (_db.update(_db.subtasks)..where((s) => s.id.equals(subtaskId)))
        .write(SubtasksCompanion(status: Value(next)));
  }

  Future<int> deleteSubtask(int subtaskId) =>
      (_db.delete(_db.subtasks)..where((s) => s.id.equals(subtaskId))).go();

  Future<void> updateSubtaskTitle(int subtaskId, String title) =>
      (_db.update(_db.subtasks)..where((s) => s.id.equals(subtaskId))).write(
        SubtasksCompanion(title: Value(title)),
      );

  // ── Due-date queries (for calendar) ─────────────────────────────

  Future<List<Item>> getItemsDueInRange(DateTime start, DateTime end) {
    final startStr = _dateFmt.format(start);
    final endStr = _dateFmt.format(end);
    return (_db.select(_db.items)..where(
          (i) =>
              i.dueDate.isNotNull() &
              i.dueDate.isBiggerOrEqualValue(startStr) &
              i.dueDate.isSmallerOrEqualValue(endStr),
        ))
        .get();
  }

  Future<List<Item>> getItemsDueOn(String dateIso) =>
      (_db.select(_db.items)..where((i) => i.dueDate.equals(dateIso))).get();
}

// ── Riverpod provider ──────────────────────────────────────────────────────────

final itemRepositoryProvider = Provider<ItemRepository>(
  (ref) => ItemRepository(ref.watch(appDatabaseProvider)),
);
