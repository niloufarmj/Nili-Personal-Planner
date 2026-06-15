import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_planner/core/db/database.dart';
import 'package:personal_planner/features/lists/repositories/collection_repository.dart';

AppDatabase _inMemory() => AppDatabase(NativeDatabase.memory());

void main() {
  late AppDatabase db;
  late CollectionRepository repo;

  setUp(() {
    db = _inMemory();
    repo = CollectionRepository(db);
  });

  tearDown(() => db.close());

  // ── create / read ────────────────────────────────────────────────

  test('create and retrieve a collection', () async {
    final id = await repo.create(name: 'Chores', template: 'chore');
    final col = await repo.getById(id);
    expect(col, isNotNull);
    expect(col!.name, 'Chores');
    expect(col.template, 'chore');
    expect(col.archived, isFalse);
  });

  test('create child collection with parentId', () async {
    final parentId = await repo.create(name: 'Job Hunt', template: 'job');
    final childId = await repo.create(
      name: 'Germany',
      template: 'job',
      parentId: parentId,
    );
    final child = await repo.getById(childId);
    expect(child!.parentId, parentId);
  });

  // ── rename ───────────────────────────────────────────────────────

  test('rename a collection', () async {
    final id = await repo.create(name: 'Old Name', template: 'simple');
    await repo.rename(id, 'New Name');
    final col = await repo.getById(id);
    expect(col!.name, 'New Name');
  });

  // ── archive ──────────────────────────────────────────────────────

  test('archive excludes from default watch', () async {
    await repo.create(name: 'Active', template: 'simple');
    final archivedId = await repo.create(name: 'Archived', template: 'simple');
    await repo.archive(archivedId);

    final emitted = <List<Collection>>[];
    final sub = repo.watchAll().listen(emitted.add);
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(emitted.last.any((c) => c.id == archivedId), isFalse);
    expect(emitted.last.any((c) => c.name == 'Active'), isTrue);
  });

  test('includeArchived: true shows archived', () async {
    final archivedId = await repo.create(name: 'Archived', template: 'simple');
    await repo.archive(archivedId);

    final emitted = <List<Collection>>[];
    final sub = repo.watchAll(includeArchived: true).listen(emitted.add);
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(emitted.last.any((c) => c.id == archivedId), isTrue);
  });

  // ── watchCollections parentId filter ────────────────────────────

  test('watchCollections(parentId: null) returns top-level only', () async {
    final parentId = await repo.create(name: 'Parent', template: 'job');
    await repo.create(name: 'Child', template: 'job', parentId: parentId);

    final emitted = <List<Collection>>[];
    final sub = repo.watchCollections().listen(emitted.add);
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(emitted.last.length, 1);
    expect(emitted.last.first.name, 'Parent');
  });

  test('watchCollections(parentId: id) returns children', () async {
    final parentId = await repo.create(name: 'Parent', template: 'job');
    await repo.create(name: 'Child', template: 'job', parentId: parentId);

    final emitted = <List<Collection>>[];
    final sub = repo.watchCollections(parentId: parentId).listen(emitted.add);
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(emitted.last.length, 1);
    expect(emitted.last.first.name, 'Child');
  });

  // ── stream emits on change ───────────────────────────────────────

  test('watchAll emits new item after create', () async {
    final emissions = <List<Collection>>[];
    final sub = repo.watchAll().listen(emissions.add);
    await Future<void>.delayed(Duration.zero);

    await repo.create(name: 'New List', template: 'simple');
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(emissions.length, greaterThan(1));
    expect(emissions.last.any((c) => c.name == 'New List'), isTrue);
  });

  // ── delete ───────────────────────────────────────────────────────

  test('delete removes collection', () async {
    final id = await repo.create(name: 'To Delete', template: 'simple');
    await repo.delete(id);
    final col = await repo.getById(id);
    expect(col, isNull);
  });
}
