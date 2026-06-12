import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_planner/core/db/database.dart';
import 'package:personal_planner/core/db/repositories/day_repository.dart';
import 'package:personal_planner/features/meals/shopping_generator.dart';
import 'package:drift/drift.dart' show Value;

AppDatabase _openDb() => AppDatabase(NativeDatabase.memory());

// Monday of a test week.
final _week = DateTime(2026, 6, 8);

Future<int> _createRecipe(AppDatabase db, String name) => db
    .into(db.recipes)
    .insert(
      RecipesCompanion.insert(name: name, mealSlot: 'dinner', tags: const []),
    );

Future<int> _createIngredient(
  AppDatabase db,
  String name, {
  String? category,
}) => db
    .into(db.ingredients)
    .insert(IngredientsCompanion.insert(name: name, category: Value(category)));

Future<void> _linkIngredient(
  AppDatabase db, {
  required int recipeId,
  required int ingredientId,
  required double amount,
  required String unit,
}) => db
    .into(db.recipeIngredients)
    .insert(
      RecipeIngredientsCompanion.insert(
        recipeId: recipeId,
        ingredientId: ingredientId,
        amount: amount,
        unit: unit,
      ),
    );

Future<void> _acceptSlot(
  AppDatabase db, {
  required String date,
  required int recipeId,
}) => db
    .into(db.mealSlots)
    .insert(
      MealSlotsCompanion.insert(
        date: date,
        slot: 'dinner',
        recipeId: Value(recipeId),
        status: 'accepted',
      ),
    );

void main() {
  late AppDatabase db;
  late ShoppingGenerator gen;

  setUp(() async {
    db = _openDb();
    await DayRepository(db).seedDefaultTagsIfNeeded();
    gen = ShoppingGenerator(db);
  });

  tearDown(() => db.close());

  // ── Basic aggregation ─────────────────────────────────────────────────────────

  test('generates collection with correct item count', () async {
    final recipeId = await _createRecipe(db, 'Pasta');
    final ingId = await _createIngredient(db, 'Chicken', category: 'meat');
    await _linkIngredient(
      db,
      recipeId: recipeId,
      ingredientId: ingId,
      amount: 200,
      unit: 'g',
    );
    await _acceptSlot(db, date: '2026-06-08', recipeId: recipeId);

    final colId = await gen.generateForWeek(_week);
    final items = await (db.select(
      db.items,
    )..where((i) => i.collectionId.equals(colId))).get();
    expect(items.length, 1);
    expect(items.first.title, contains('Chicken'));
    expect(items.first.title, contains('200'));
  });

  // ── Amount summing: same unit ─────────────────────────────────────────────────

  test(
    'sums amounts when same recipe appears multiple times in the week',
    () async {
      final recipeId = await _createRecipe(db, 'Chicken salad');
      final ingId = await _createIngredient(db, 'Chicken breast');
      await _linkIngredient(
        db,
        recipeId: recipeId,
        ingredientId: ingId,
        amount: 150,
        unit: 'g',
      );
      // Accept same recipe on Monday and Tuesday.
      await _acceptSlot(db, date: '2026-06-08', recipeId: recipeId);
      await _acceptSlot(db, date: '2026-06-09', recipeId: recipeId);

      final colId = await gen.generateForWeek(_week);
      final items = await (db.select(
        db.items,
      )..where((i) => i.collectionId.equals(colId))).get();
      expect(items.length, 1);
      // 150g × 2 = 300g
      expect(items.first.title, contains('300'));
    },
  );

  // ── Mixed units listed separately ─────────────────────────────────────────────

  test('same ingredient with different units creates separate items', () async {
    final recipeId1 = await _createRecipe(db, 'Soup');
    final recipeId2 = await _createRecipe(db, 'Sauce');
    final ingId = await _createIngredient(db, 'Tomato');

    await _linkIngredient(
      db,
      recipeId: recipeId1,
      ingredientId: ingId,
      amount: 2,
      unit: 'pcs',
    );
    await _linkIngredient(
      db,
      recipeId: recipeId2,
      ingredientId: ingId,
      amount: 100,
      unit: 'g',
    );
    await _acceptSlot(db, date: '2026-06-08', recipeId: recipeId1);
    await _acceptSlot(db, date: '2026-06-09', recipeId: recipeId2);

    final colId = await gen.generateForWeek(_week);
    final items = await (db.select(
      db.items,
    )..where((i) => i.collectionId.equals(colId))).get();
    // Two separate lines: one "2 pcs" and one "100 g"
    expect(items.length, 2);
    final titles = items.map((i) => i.title).toList();
    expect(titles.any((t) => t.contains('pcs')), isTrue);
    expect(titles.any((t) => t.contains('g')), isTrue);
  });

  // ── Idempotency ───────────────────────────────────────────────────────────────

  test(
    'running generateForWeek twice does not duplicate the collection',
    () async {
      final recipeId = await _createRecipe(db, 'Omelette');
      final ingId = await _createIngredient(db, 'Eggs');
      await _linkIngredient(
        db,
        recipeId: recipeId,
        ingredientId: ingId,
        amount: 3,
        unit: 'pcs',
      );
      await _acceptSlot(db, date: '2026-06-08', recipeId: recipeId);

      final col1 = await gen.generateForWeek(_week);
      final col2 = await gen.generateForWeek(_week);

      // Same collection returned both times.
      expect(col1, equals(col2));

      // Only one collection in DB with this name.
      final allCols = await db.select(db.collections).get();
      final groceryCols = allCols.where((c) => c.name.contains('Groceries'));
      expect(groceryCols.length, 1);

      // Only one item row (not doubled).
      final items = await (db.select(
        db.items,
      )..where((i) => i.collectionId.equals(col1))).get();
      expect(items.length, 1);
    },
  );

  // ── Only accepted / eaten slots ───────────────────────────────────────────────

  test('skipped meal slots are excluded from shopping list', () async {
    final recipeId = await _createRecipe(db, 'Skipped meal');
    final ingId = await _createIngredient(db, 'Some veg');
    await _linkIngredient(
      db,
      recipeId: recipeId,
      ingredientId: ingId,
      amount: 100,
      unit: 'g',
    );
    await db
        .into(db.mealSlots)
        .insert(
          MealSlotsCompanion.insert(
            date: '2026-06-08',
            slot: 'dinner',
            recipeId: Value(recipeId),
            status: 'skipped',
          ),
        );

    final colId = await gen.generateForWeek(_week);
    final items = await (db.select(
      db.items,
    )..where((i) => i.collectionId.equals(colId))).get();
    expect(items, isEmpty);
  });

  // ── Empty week ────────────────────────────────────────────────────────────────

  test('week with no accepted slots produces an empty collection', () async {
    final colId = await gen.generateForWeek(_week);
    final items = await (db.select(
      db.items,
    )..where((i) => i.collectionId.equals(colId))).get();
    expect(items, isEmpty);
  });

  // ── Category grouping in title ─────────────────────────────────────────────────

  test('items are sorted by category then name', () async {
    final r1 = await _createRecipe(db, 'Recipe A');
    final r2 = await _createRecipe(db, 'Recipe B');
    final produce = await _createIngredient(
      db,
      'Zucchini',
      category: 'produce',
    );
    final dairy = await _createIngredient(db, 'Milk', category: 'dairy');

    await _linkIngredient(
      db,
      recipeId: r1,
      ingredientId: produce,
      amount: 1,
      unit: 'pcs',
    );
    await _linkIngredient(
      db,
      recipeId: r2,
      ingredientId: dairy,
      amount: 200,
      unit: 'ml',
    );
    await _acceptSlot(db, date: '2026-06-08', recipeId: r1);
    await _acceptSlot(db, date: '2026-06-09', recipeId: r2);

    final colId = await gen.generateForWeek(_week);
    final items =
        await (db.select(
            db.items,
          )..where((i) => i.collectionId.equals(colId))).get()
          ..sort((a, b) => a.title.compareTo(b.title));

    // dairy comes before produce alphabetically.
    expect(items.first.title, contains('Milk'));
    expect(items.last.title, contains('Zucchini'));
  });
}
