import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';

/// A recipe with its resolved ingredient rows.
class RecipeWithIngredients {
  const RecipeWithIngredients({required this.recipe, required this.rows});
  final Recipe recipe;
  final List<RecipeIngredientRow> rows;
}

/// Joined row: recipe_ingredient + ingredient name/category.
class RecipeIngredientRow {
  const RecipeIngredientRow({
    required this.ingredient,
    required this.amount,
    required this.unit,
  });
  final Ingredient ingredient;
  final double amount;
  final String unit;
}

class RecipeRepository {
  RecipeRepository(this._db);

  final AppDatabase _db;

  // ── Queries ──────────────────────────────────────────────────────

  Stream<List<Recipe>> watchAll() => (_db.select(
    _db.recipes,
  )..orderBy([(r) => OrderingTerm(expression: r.name)])).watch();

  Future<List<Recipe>> getAll() => (_db.select(
    _db.recipes,
  )..orderBy([(r) => OrderingTerm(expression: r.name)])).get();

  Future<List<Recipe>> getBySlot(String slot) => (_db.select(
    _db.recipes,
  )..where((r) => r.mealSlot.equals(slot) | r.mealSlot.equals('any'))).get();

  Future<List<Recipe>> getByTags(List<String> tags) async {
    final all = await getAll();
    return all.where((r) => tags.every((t) => r.tags.contains(t))).toList();
  }

  Future<List<Recipe>> search(String query) =>
      (_db.select(_db.recipes)..where((r) => r.name.like('%$query%'))).get();

  Future<Recipe?> getById(int id) async {
    final rows = await (_db.select(
      _db.recipes,
    )..where((r) => r.id.equals(id))).get();
    return rows.isEmpty ? null : rows.first;
  }

  Future<RecipeWithIngredients?> getWithIngredients(int recipeId) async {
    final recipe = await getById(recipeId);
    if (recipe == null) return null;
    final rows = await _ingredientRows(recipeId);
    return RecipeWithIngredients(recipe: recipe, rows: rows);
  }

  Future<List<RecipeIngredientRow>> _ingredientRows(int recipeId) async {
    final riRows = await (_db.select(
      _db.recipeIngredients,
    )..where((ri) => ri.recipeId.equals(recipeId))).get();
    if (riRows.isEmpty) return [];
    final ids = riRows.map((r) => r.ingredientId).toList();
    final ings = await (_db.select(
      _db.ingredients,
    )..where((i) => i.id.isIn(ids))).get();
    final ingMap = {for (final i in ings) i.id: i};
    return riRows
        .map((r) {
          final ing = ingMap[r.ingredientId];
          if (ing == null) return null;
          return RecipeIngredientRow(
            ingredient: ing,
            amount: r.amount,
            unit: r.unit,
          );
        })
        .whereType<RecipeIngredientRow>()
        .toList();
  }

  // ── Create / update / delete ─────────────────────────────────────

  Future<int> create({
    required String name,
    required String mealSlot,
    int? prepMinutes,
    required List<String> tags,
    String? instructions,
    String? image,
  }) => _db
      .into(_db.recipes)
      .insert(
        RecipesCompanion.insert(
          name: name,
          mealSlot: mealSlot,
          prepMinutes: Value(prepMinutes),
          tags: tags,
          instructions: Value(instructions),
          image: Value(image),
        ),
      );

  Future<void> update(Recipe recipe) => _db.update(_db.recipes).replace(recipe);

  Future<void> setIngredients(
    int recipeId,
    List<RecipeIngredientRow> rows,
  ) async {
    await (_db.delete(
      _db.recipeIngredients,
    )..where((ri) => ri.recipeId.equals(recipeId))).go();
    for (final row in rows) {
      await _db
          .into(_db.recipeIngredients)
          .insert(
            RecipeIngredientsCompanion.insert(
              recipeId: recipeId,
              ingredientId: row.ingredient.id,
              amount: row.amount,
              unit: row.unit,
            ),
          );
    }
  }

  Future<void> delete(int id) async {
    await (_db.delete(
      _db.recipeIngredients,
    )..where((ri) => ri.recipeId.equals(id))).go();
    await (_db.delete(_db.recipes)..where((r) => r.id.equals(id))).go();
  }
}

final recipeRepositoryProvider = Provider<RecipeRepository>(
  (ref) => RecipeRepository(ref.watch(appDatabaseProvider)),
);
