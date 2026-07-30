import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';

class IngredientRepository {
  IngredientRepository(this._db);

  final AppDatabase _db;

  Stream<List<Ingredient>> watchAll() => (_db.select(
    _db.ingredients,
  )..orderBy([(i) => OrderingTerm(expression: i.name)])).watch();

  Future<List<Ingredient>> getAll() => (_db.select(
    _db.ingredients,
  )..orderBy([(i) => OrderingTerm(expression: i.name)])).get();

  Future<List<Ingredient>> search(String query) =>
      (_db.select(_db.ingredients)
            ..where((i) => i.name.like('%$query%'))
            ..orderBy([(i) => OrderingTerm(expression: i.name)]))
          .get();

  Future<Ingredient?> getByName(String name) async {
    final rows = await (_db.select(
      _db.ingredients,
    )..where((i) => i.name.equals(name))).get();
    return rows.isEmpty ? null : rows.first;
  }

  /// Returns existing or creates a new ingredient (dedup on exact name).
  Future<int> findOrCreate(String name, {String? category}) async {
    final existing = await getByName(name.trim());
    if (existing != null) return existing.id;
    return _db
        .into(_db.ingredients)
        .insert(
          IngredientsCompanion.insert(
            name: name.trim(),
            category: Value(category),
          ),
        );
  }

  Future<int> create({
    required String name,
    String? category,
    double? kcalPer100g,
    double? proteinPer100g,
    String? image,
    double? estimatedCost,
  }) => _db
      .into(_db.ingredients)
      .insert(
        IngredientsCompanion.insert(
          name: name,
          category: Value(category),
          kcalPer100g: Value(kcalPer100g),
          proteinPer100g: Value(proteinPer100g),
          image: Value(image),
          estimatedCost: Value(estimatedCost),
        ),
      );

  Future<void> update(Ingredient ingredient) =>
      _db.update(_db.ingredients).replace(ingredient);

  Future<void> toggleInStock(int id, bool inStock) =>
      (_db.update(_db.ingredients)..where((i) => i.id.equals(id)))
          .write(IngredientsCompanion(inStock: Value(inStock)));

  Stream<List<Ingredient>> watchInStock(bool inStock) =>
      (_db.select(_db.ingredients)
            ..where((i) => i.inStock.equals(inStock))
            ..orderBy([(i) => OrderingTerm(expression: i.name)]))
          .watch();

  /// Returns missing ingredients (where inStock == false) required for [recipeId].
  Future<List<Ingredient>> getMissingIngredientsForRecipe(int recipeId) async {
    final query = _db.select(_db.recipeIngredients).join([
      innerJoin(
        _db.ingredients,
        _db.ingredients.id.equalsExp(_db.recipeIngredients.ingredientId),
      ),
    ])
      ..where(
        _db.recipeIngredients.recipeId.equals(recipeId) &
            _db.ingredients.inStock.equals(false),
      );

    final rows = await query.get();
    return rows.map((r) => r.readTable(_db.ingredients)).toList();
  }

  Future<void> delete(int id) =>
      (_db.delete(_db.ingredients)..where((i) => i.id.equals(id))).go();
}

final ingredientRepositoryProvider = Provider<IngredientRepository>(
  (ref) => IngredientRepository(ref.watch(appDatabaseProvider)),
);
