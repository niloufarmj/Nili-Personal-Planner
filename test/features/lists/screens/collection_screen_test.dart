import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_planner/core/db/database.dart';
import 'package:personal_planner/core/design/design.dart';
import 'package:personal_planner/features/lists/repositories/collection_repository.dart';
import 'package:personal_planner/features/lists/repositories/item_repository.dart';
import 'package:personal_planner/features/lists/screens/collection_screen.dart';

Widget _wrap(Widget child, AppDatabase db) => ProviderScope(
  overrides: [appDatabaseProvider.overrideWithValue(db)],
  child: MaterialApp(home: child),
);

// pumpAndSettle lets all StreamProviders resolve + animations finish.
// _disposeAndFlush must be called at the END of each test body (not in
// addTearDown) so drift's zero-duration cleanup timer fires inside FakeAsync.
Future<void> _disposeAndFlush(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 1));
}

void main() {
  late AppDatabase db;
  late CollectionRepository collRepo;
  late ItemRepository itemRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    collRepo = CollectionRepository(db);
    itemRepo = ItemRepository(db);
  });
  tearDown(() => db.close());

  // ── Empty state ──────────────────────────────────────────────────

  testWidgets('shows empty state when collection has no items', (tester) async {
    final colId = await collRepo.create(name: 'Chores', template: 'simple');

    await tester.pumpWidget(_wrap(CollectionScreen(collectionId: colId), db));
    await tester.pumpAndSettle();

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('No items yet'), findsOneWidget);

    await _disposeAndFlush(tester);
  });

  // ── simple template — item list ──────────────────────────────────

  testWidgets('simple template: item appears after creation', (tester) async {
    final colId = await collRepo.create(name: 'Tasks', template: 'simple');
    await itemRepo.createItem(
      ItemsCompanion.insert(collectionId: colId, title: 'Buy eggs'),
    );

    await tester.pumpWidget(_wrap(CollectionScreen(collectionId: colId), db));
    await tester.pumpAndSettle();

    expect(find.text('Buy eggs'), findsOneWidget);
    expect(find.byType(EmptyState), findsNothing);

    await _disposeAndFlush(tester);
  });

  // ── task template — subtasks inline ─────────────────────────────

  testWidgets('task template: subtask row visible when expanded', (
    tester,
  ) async {
    final colId = await collRepo.create(name: 'Project', template: 'task');
    final itemId = await itemRepo.createItem(
      ItemsCompanion.insert(collectionId: colId, title: 'Write report'),
    );
    await itemRepo.createSubtask(itemId: itemId, title: 'Research');

    await tester.pumpWidget(_wrap(CollectionScreen(collectionId: colId), db));
    await tester.pumpAndSettle();

    // pumpAndSettle after tap waits for SubtaskList's StreamProvider to emit.
    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();

    expect(find.text('Research'), findsOneWidget);

    await _disposeAndFlush(tester);
  });

  // ── shopping template — cost chip visible ───────────────────────

  testWidgets('shopping template: planned cost chip rendered', (tester) async {
    final colId = await collRepo.create(name: 'Shopping', template: 'shopping');
    await itemRepo.createItem(
      ItemsCompanion.insert(
        collectionId: colId,
        title: 'Headphones',
        plannedCostCents: const Value(15000),
      ),
    );

    await tester.pumpWidget(_wrap(CollectionScreen(collectionId: colId), db));
    await tester.pumpAndSettle();

    expect(find.text('Headphones'), findsOneWidget);
    expect(find.text('€150.00'), findsOneWidget);

    await _disposeAndFlush(tester);
  });

  // ── Empty-state action opens add-item sheet ──────────────────────

  testWidgets('empty-state action opens add-item sheet', (tester) async {
    final colId = await collRepo.create(name: 'My List', template: 'simple');

    await tester.pumpWidget(_wrap(CollectionScreen(collectionId: colId), db));
    await tester.pumpAndSettle();

    // The EmptyState "Add item" button calls the same _openAddSheet as the FAB.
    await tester.tap(find.text('Add item'));
    await tester.pumpAndSettle();

    expect(find.text('New item'), findsOneWidget);
    expect(find.byType(TextFormField), findsWidgets);

    await _disposeAndFlush(tester);
  });

  // ── upgrade template — image slots rendered (no actual images) ───

  testWidgets('upgrade template: image before/after row rendered', (
    tester,
  ) async {
    final colId = await collRepo.create(name: 'Upgrades', template: 'upgrade');
    await itemRepo.createItem(
      ItemsCompanion.insert(
        collectionId: colId,
        title: 'New desk',
        imageBefore: const Value('/some/path/before.jpg'),
      ),
    );

    await tester.pumpWidget(_wrap(CollectionScreen(collectionId: colId), db));
    await tester.pumpAndSettle();

    expect(find.text('New desk'), findsOneWidget);
    // Image slot renders with "Before" label
    expect(find.text('Before'), findsOneWidget);

    await _disposeAndFlush(tester);
  });
}
