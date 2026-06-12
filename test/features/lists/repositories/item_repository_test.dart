import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_planner/core/db/database.dart';
import 'package:personal_planner/features/lists/repositories/collection_repository.dart';
import 'package:personal_planner/features/lists/repositories/item_repository.dart';

AppDatabase _inMemory() => AppDatabase(NativeDatabase.memory());

void main() {
  late AppDatabase db;
  late CollectionRepository collRepo;
  late ItemRepository repo;
  late int colId;

  setUp(() async {
    db = _inMemory();
    collRepo = CollectionRepository(db);
    repo = ItemRepository(db);
    colId = await collRepo.create(name: 'Test', template: 'simple');
  });

  tearDown(() => db.close());

  // ── create / read ────────────────────────────────────────────────

  test('createItem and getById', () async {
    final id = await repo.createItem(
      ItemsCompanion.insert(collectionId: colId, title: 'Buy milk'),
    );
    final item = await repo.getById(id);
    expect(item, isNotNull);
    expect(item!.title, 'Buy milk');
    expect(item.status, 'open');
    expect(item.doneDate, isNull);
  });

  // ── toggleItemStatus sets done_date ──────────────────────────────

  test('toggleItemStatus sets done_date on tick', () async {
    final id = await repo.createItem(
      ItemsCompanion.insert(collectionId: colId, title: 'Clean'),
    );
    await repo.toggleItemStatus(id, doneStatus: 'done', openStatus: 'open');
    final item = await repo.getById(id);
    expect(item!.status, 'done');
    expect(item.doneDate, isNotNull);
  });

  test('toggleItemStatus clears done_date on untick', () async {
    final id = await repo.createItem(
      ItemsCompanion.insert(collectionId: colId, title: 'Clean'),
    );
    // Tick
    await repo.toggleItemStatus(id, doneStatus: 'done', openStatus: 'open');
    // Untick
    await repo.toggleItemStatus(id, doneStatus: 'done', openStatus: 'open');
    final item = await repo.getById(id);
    expect(item!.status, 'open');
    expect(item.doneDate, isNull);
  });

  // ── watchItems emits on change ───────────────────────────────────

  test('watchItems emits new item after create', () async {
    final emissions = <List<Item>>[];
    final sub = repo.watchItems(colId).listen(emissions.add);
    await Future<void>.delayed(Duration.zero);

    await repo.createItem(
      ItemsCompanion.insert(collectionId: colId, title: 'New task'),
    );
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(emissions.last.any((i) => i.title == 'New task'), isTrue);
  });

  // ── sorting: priority then due_date ─────────────────────────────

  test('watchItems sorts by priority then due_date', () async {
    await repo.createItem(
      ItemsCompanion.insert(
        collectionId: colId,
        title: 'Low prio',
        priority: const Value(3),
        dueDate: const Value('2026-06-20'),
      ),
    );
    await repo.createItem(
      ItemsCompanion.insert(
        collectionId: colId,
        title: 'High prio',
        priority: const Value(1),
        dueDate: const Value('2026-06-25'),
      ),
    );
    await repo.createItem(
      ItemsCompanion.insert(
        collectionId: colId,
        title: 'Normal early due',
        priority: const Value(2),
        dueDate: const Value('2026-06-15'),
      ),
    );

    final emitted = <List<Item>>[];
    final sub = repo.watchItems(colId).listen(emitted.add);
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    final titles = emitted.last.map((i) => i.title).toList();
    expect(titles[0], 'High prio');
    expect(titles[1], 'Normal early due');
    expect(titles[2], 'Low prio');
  });

  // ── subtasks ─────────────────────────────────────────────────────

  test('createSubtask and watchSubtasks', () async {
    final itemId = await repo.createItem(
      ItemsCompanion.insert(collectionId: colId, title: 'Project'),
    );
    await repo.createSubtask(itemId: itemId, title: 'Sub 1');
    await repo.createSubtask(itemId: itemId, title: 'Sub 2');

    final subs = await repo.getSubtasks(itemId);
    expect(subs.length, 2);
    expect(subs.map((s) => s.title), containsAll(['Sub 1', 'Sub 2']));
  });

  test('toggleSubtask toggles status', () async {
    final itemId = await repo.createItem(
      ItemsCompanion.insert(collectionId: colId, title: 'Project'),
    );
    final subId = await repo.createSubtask(itemId: itemId, title: 'Sub 1');

    await repo.toggleSubtask(subId);
    final subs1 = await repo.getSubtasks(itemId);
    expect(subs1.first.status, 'done');

    await repo.toggleSubtask(subId);
    final subs2 = await repo.getSubtasks(itemId);
    expect(subs2.first.status, 'open');
  });

  test('deleteSubtask removes it', () async {
    final itemId = await repo.createItem(
      ItemsCompanion.insert(collectionId: colId, title: 'Project'),
    );
    final subId = await repo.createSubtask(itemId: itemId, title: 'Remove me');
    await repo.deleteSubtask(subId);
    final subs = await repo.getSubtasks(itemId);
    expect(subs, isEmpty);
  });

  // ── due date queries ─────────────────────────────────────────────

  test('getItemsDueOn returns matching items', () async {
    await repo.createItem(
      ItemsCompanion.insert(
        collectionId: colId,
        title: 'Due today',
        dueDate: const Value('2026-06-11'),
      ),
    );
    await repo.createItem(
      ItemsCompanion.insert(
        collectionId: colId,
        title: 'Due tomorrow',
        dueDate: const Value('2026-06-12'),
      ),
    );
    final items = await repo.getItemsDueOn('2026-06-11');
    expect(items.length, 1);
    expect(items.first.title, 'Due today');
  });

  // ── delete ───────────────────────────────────────────────────────

  test('deleteItem removes item', () async {
    final id = await repo.createItem(
      ItemsCompanion.insert(collectionId: colId, title: 'Temp'),
    );
    await repo.deleteItem(id);
    expect(await repo.getById(id), isNull);
  });
}
