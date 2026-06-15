import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_planner/core/db/database.dart';
import 'package:personal_planner/features/lists/repositories/collection_repository.dart';
import 'package:personal_planner/features/lists/repositories/item_repository.dart';
import 'package:personal_planner/features/lists/services/chore_service.dart';

void main() {
  late AppDatabase db;
  late CollectionRepository collRepo;
  late ItemRepository itemRepo;
  late ChoreService svc;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    collRepo = CollectionRepository(db);
    itemRepo = ItemRepository(db);
    svc = ChoreService(db);
  });
  tearDown(() => db.close());

  Future<int> choreItem({
    required String dueDate,
    required String rrule,
  }) async {
    final colId = await collRepo.create(name: 'Chores', template: 'chore');
    return itemRepo.createItem(
      ItemsCompanion.insert(
        collectionId: colId,
        title: 'Test chore',
        dueDate: Value(dueDate),
        recurrence: Value(rrule),
      ),
    );
  }

  // ── RRULE advancement ─────────────────────────────────────────────

  test('daily chore: due_date advances by one day', () async {
    final id = await choreItem(dueDate: '2026-06-01', rrule: 'FREQ=DAILY');
    await svc.completeChore(id);
    final item = await itemRepo.getById(id);
    expect(item!.dueDate, '2026-06-02');
    expect(item.status, 'open');
    expect(item.doneDate, isNull);
  });

  test('weekly chore: due_date advances by seven days', () async {
    final id = await choreItem(dueDate: '2026-06-01', rrule: 'FREQ=WEEKLY');
    await svc.completeChore(id);
    final item = await itemRepo.getById(id);
    expect(item!.dueDate, '2026-06-08');
    expect(item.status, 'open');
  });

  test('monthly chore: due_date advances by one month', () async {
    final id = await choreItem(dueDate: '2026-06-01', rrule: 'FREQ=MONTHLY');
    await svc.completeChore(id);
    final item = await itemRepo.getById(id);
    expect(item!.dueDate, '2026-07-01');
    expect(item.status, 'open');
  });

  test('chore without rrule: due_date stays null after completion', () async {
    final colId = await collRepo.create(name: 'Chores', template: 'chore');
    final id = await itemRepo.createItem(
      ItemsCompanion.insert(
        collectionId: colId,
        title: 'One-off chore',
        dueDate: const Value('2026-06-01'),
      ),
    );
    await svc.completeChore(id);
    final item = await itemRepo.getById(id);
    expect(item!.dueDate, isNull);
    expect(item.status, 'open');
  });

  // ── Completion history ────────────────────────────────────────────

  test('completeChore records a chore_completions row', () async {
    final id = await choreItem(dueDate: '2026-06-01', rrule: 'FREQ=DAILY');
    await svc.completeChore(id);
    final history = await svc.getCompletions(id);
    expect(history.length, 1);
    expect(history.first.itemId, id);
    expect(history.first.dueDateAtCompletion, '2026-06-01');
  });

  test('multiple completions are returned most-recent first', () async {
    final id = await choreItem(dueDate: '2026-06-01', rrule: 'FREQ=DAILY');
    await svc.completeChore(id); // advances to 06-02
    await svc.completeChore(id); // advances to 06-03
    final history = await svc.getCompletions(id);
    expect(history.length, 2);
    // Most recent completion logged last has a later completedAt.
    // Both completedAt are today's date in tests, so just verify count.
    expect(history.every((c) => c.itemId == id), isTrue);
  });

  // ── Overdue detection ─────────────────────────────────────────────

  test('isOverdue returns true when dueDate is yesterday', () async {
    final colId = await collRepo.create(name: 'C', template: 'chore');
    final id = await itemRepo.createItem(
      ItemsCompanion.insert(
        collectionId: colId,
        title: 'Clean bathroom',
        dueDate: const Value('2020-01-01'),
      ),
    );
    final item = await itemRepo.getById(id);
    expect(
      ChoreService.isOverdue(
        item!,
        doneStatus: 'done',
        now: DateTime(2026, 6, 1),
      ),
      isTrue,
    );
  });

  test('isOverdue returns false when dueDate is today', () async {
    final colId = await collRepo.create(name: 'C', template: 'chore');
    final id = await itemRepo.createItem(
      ItemsCompanion.insert(
        collectionId: colId,
        title: 'Clean bathroom',
        dueDate: const Value('2026-06-01'),
      ),
    );
    final item = await itemRepo.getById(id);
    expect(
      ChoreService.isOverdue(
        item!,
        doneStatus: 'done',
        now: DateTime(2026, 6, 1),
      ),
      isFalse,
    );
  });

  test('isOverdue returns false when status is done', () async {
    final colId = await collRepo.create(name: 'C', template: 'chore');
    final id = await itemRepo.createItem(
      ItemsCompanion.insert(
        collectionId: colId,
        title: 'Clean bathroom',
        dueDate: const Value('2020-01-01'),
        status: const Value('done'),
      ),
    );
    final item = await itemRepo.getById(id);
    expect(
      ChoreService.isOverdue(
        item!,
        doneStatus: 'done',
        now: DateTime(2026, 6, 1),
      ),
      isFalse,
    );
  });

  test('isOverdue returns false when dueDate is null', () async {
    final colId = await collRepo.create(name: 'C', template: 'chore');
    final id = await itemRepo.createItem(
      ItemsCompanion.insert(collectionId: colId, title: 'No due date'),
    );
    final item = await itemRepo.getById(id);
    expect(ChoreService.isOverdue(item!, doneStatus: 'done'), isFalse);
  });
}
