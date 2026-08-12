import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import 'ingredient_repository.dart';
import 'meal_slot_repository.dart';

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
    int? proteinGrams,
    int? calories,
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
          proteinGrams: Value(proteinGrams),
          calories: Value(calories),
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

  Future<void> seedDefaultRecipesIfNeeded(
    IngredientRepository ingredientRepo,
    MealSlotRepository mealSlotRepo,
  ) async {
    final existing = await getAll();
    if (existing.isNotEmpty) return;

    final defaultRecipes = [
      {
        'name': 'Fried Egg & Toast with Sausage',
        'slot': 'breakfast',
        'prep': 10,
        'protein': 22,
        'calories': 380,
        'tags': ['breakfast', 'high-protein', 'quick'],
        'instructions':
            'Spray pan with olive oil spray. Fry egg sunny-side up. Toast 1 slice of bread. Serve fried egg over toast alongside pan-seared sausage slice.',
        'ingredients': [
          {'name': 'تخم‌مرغ', 'amount': 2.0, 'unit': 'pcs', 'cat': 'protein'},
          {'name': 'نون تست', 'amount': 1.0, 'unit': 'slice', 'cat': 'bakery'},
          {'name': 'سوسیس', 'amount': 50.0, 'unit': 'g', 'cat': 'protein'},
          {'name': 'اسپری روغن زیتون', 'amount': 1.0, 'unit': 'spray', 'cat': 'pantry'},
        ],
      },
      {
        'name': 'Chicken Caesar Salad',
        'slot': 'lunch',
        'prep': 15,
        'protein': 38,
        'calories': 420,
        'tags': ['lunch', 'salad', 'high-protein', '30%veggies'],
        'instructions':
            'Season chicken breast cubes and cook with olive oil spray. Chop fresh lettuce into bowl. Add croutons, warm chicken cubes, and sprinkle grated parmesan cheese.',
        'ingredients': [
          {'name': 'مرغ', 'amount': 150.0, 'unit': 'g', 'cat': 'protein'},
          {'name': 'کاهو', 'amount': 150.0, 'unit': 'g', 'cat': 'produce'},
          {'name': 'نون سوخاری', 'amount': 30.0, 'unit': 'g', 'cat': 'bakery'},
          {'name': 'پنیر پارمسان', 'amount': 15.0, 'unit': 'g', 'cat': 'dairy'},
          {'name': 'اسپری روغن زیتون', 'amount': 1.0, 'unit': 'spray', 'cat': 'pantry'},
        ],
      },
      {
        'name': 'Salmon & Herb Rice with Steamed Broccoli',
        'slot': 'dinner',
        'prep': 25,
        'protein': 36,
        'calories': 520,
        'tags': ['dinner', 'seafood', 'omega3', '40carb-30prot-30veg'],
        'instructions':
            'Cook seasoned rice with diced carrots and bell peppers. Pan-sear salmon fillet with olive oil spray and herbs. Serve in bento with fresh steamed broccoli florets and green olives.',
        'ingredients': [
          {'name': 'ماهی', 'amount': 160.0, 'unit': 'g', 'cat': 'protein'},
          {'name': 'برنج', 'amount': 80.0, 'unit': 'g', 'cat': 'pantry'},
          {'name': 'کلم بروکلی', 'amount': 100.0, 'unit': 'g', 'cat': 'produce'},
          {'name': 'زیتون', 'amount': 40.0, 'unit': 'g', 'cat': 'pantry'},
          {'name': 'هویج', 'amount': 30.0, 'unit': 'g', 'cat': 'produce'},
          {'name': 'فلفل دلمه', 'amount': 30.0, 'unit': 'g', 'cat': 'produce'},
          {'name': 'اسپری روغن زیتون', 'amount': 1.0, 'unit': 'spray', 'cat': 'pantry'},
        ],
      },
      {
        'name': 'Barilla Pesto Chicken Pasta',
        'slot': 'lunch',
        'prep': 20,
        'protein': 35,
        'calories': 480,
        'tags': ['lunch', 'pasta', 'pesto'],
        'instructions':
            'Boil pasta and broccoli. Sauté diced chicken breast and garlic with olive oil spray. Toss cooked pasta with Barilla pesto, sliced ring peppers, broccoli, and chicken.',
        'ingredients': [
          {'name': 'ماکارونی', 'amount': 80.0, 'unit': 'g', 'cat': 'pantry'},
          {'name': 'مرغ', 'amount': 140.0, 'unit': 'g', 'cat': 'protein'},
          {'name': 'سس پستو', 'amount': 30.0, 'unit': 'g', 'cat': 'pantry'},
          {'name': 'کلم بروکلی', 'amount': 60.0, 'unit': 'g', 'cat': 'produce'},
          {'name': 'فلفل دلمه', 'amount': 40.0, 'unit': 'g', 'cat': 'produce'},
          {'name': 'سیر', 'amount': 1.0, 'unit': 'clove', 'cat': 'produce'},
          {'name': 'اسپری روغن زیتون', 'amount': 1.0, 'unit': 'spray', 'cat': 'pantry'},
        ],
      },
      {
        'name': 'Boiled Egg & Sausage Salad',
        'slot': 'breakfast',
        'prep': 12,
        'protein': 24,
        'calories': 340,
        'tags': ['breakfast', 'egg-salad', 'low-carb'],
        'instructions':
            'Boil eggs for 9 minutes. Slice boiled eggs and sausage, serve over fresh lettuce and ring peppers.',
        'ingredients': [
          {'name': 'تخم‌مرغ', 'amount': 2.0, 'unit': 'pcs', 'cat': 'protein'},
          {'name': 'سوسیس', 'amount': 40.0, 'unit': 'g', 'cat': 'protein'},
          {'name': 'کاهو', 'amount': 50.0, 'unit': 'g', 'cat': 'produce'},
          {'name': 'فلفل دلمه', 'amount': 30.0, 'unit': 'g', 'cat': 'produce'},
        ],
      },
      {
        'name': 'Baked Beef & Veggie Lasagna',
        'slot': 'dinner',
        'prep': 45,
        'protein': 42,
        'calories': 650,
        'tags': ['dinner', 'favorite', 'baked', 'special'],
        'instructions':
            'Sauté minced beef with garlic, bell peppers, carrots, and tomato sauce. Layer lasagna sheets with beef mixture, top with mozzarella cheese, and bake at 190°C for 30 min.',
        'ingredients': [
          {'name': 'ورق لازانیا', 'amount': 100.0, 'unit': 'g', 'cat': 'pantry'},
          {'name': 'گوشت چرخ‌کرده', 'amount': 150.0, 'unit': 'g', 'cat': 'protein'},
          {'name': 'فلفل دلمه', 'amount': 50.0, 'unit': 'g', 'cat': 'produce'},
          {'name': 'هویج', 'amount': 40.0, 'unit': 'g', 'cat': 'produce'},
          {'name': 'رب گوجه', 'amount': 100.0, 'unit': 'g', 'cat': 'pantry'},
          {'name': 'پنیر پیتزا', 'amount': 50.0, 'unit': 'g', 'cat': 'dairy'},
          {'name': 'سیر', 'amount': 1.0, 'unit': 'clove', 'cat': 'produce'},
        ],
      },
      {
        'name': 'Zereshk Polo ba Morgh (Saffron Barberry Chicken Rice)',
        'slot': 'lunch',
        'prep': 40,
        'protein': 38,
        'calories': 510,
        'tags': ['lunch', 'persian', 'special', 'chicken-breast'],
        'instructions':
            'Simmer chicken breast in saffron-tomato sauce. Gently saute barberries in 1 spray olive oil. Serve tender chicken over steamed saffron basmati rice.',
        'ingredients': [
          {'name': 'مرغ', 'amount': 160.0, 'unit': 'g', 'cat': 'protein'},
          {'name': 'برنج', 'amount': 90.0, 'unit': 'g', 'cat': 'pantry'},
          {'name': 'زرشک', 'amount': 20.0, 'unit': 'g', 'cat': 'pantry'},
          {'name': 'اسپری روغن زیتون', 'amount': 1.0, 'unit': 'spray', 'cat': 'pantry'},
        ],
      },
      {
        'name': 'Fresh Banana & Mango Berry Milk Shake',
        'slot': 'shake',
        'prep': 5,
        'protein': 14,
        'calories': 280,
        'tags': ['shake', 'post-workout', 'snack'],
        'instructions':
            'Combine chilled milk, 1 banana, sliced mango, and fresh berries in blender. Blend until smooth.',
        'ingredients': [
          {'name': 'شیر', 'amount': 250.0, 'unit': 'ml', 'cat': 'dairy'},
          {'name': 'موز', 'amount': 1.0, 'unit': 'pc', 'cat': 'produce'},
          {'name': 'میوه (موز و توت‌فرنگی)', 'amount': 50.0, 'unit': 'g', 'cat': 'produce'},
        ],
      },
      {
        'name': 'Daily Sweetened Iced Coffee',
        'slot': 'snack',
        'prep': 3,
        'protein': 4,
        'calories': 90,
        'tags': ['coffee', 'daily'],
        'instructions':
            'Brew fresh espresso shot. Mix with cold milk, 1 tsp sugar, and pour over ice cubes.',
        'ingredients': [
          {'name': 'شیر', 'amount': 150.0, 'unit': 'ml', 'cat': 'dairy'},
        ],
      },
    ];

    for (final r in defaultRecipes) {
      final recipeId = await create(
        name: r['name'] as String,
        mealSlot: r['slot'] as String,
        prepMinutes: r['prep'] as int,
        proteinGrams: r['protein'] as int,
        calories: r['calories'] as int,
        tags: List<String>.from(r['tags'] as List),
        instructions: r['instructions'] as String,
      );

      final rows = <RecipeIngredientRow>[];
      final rawIngs = r['ingredients'] as List<Map<String, dynamic>>;
      for (final ingRef in rawIngs) {
        final name = ingRef['name'] as String;
        final cat = ingRef['cat'] as String;
        var ing = await ingredientRepo.getByName(name);
        if (ing == null) {
          final id = await ingredientRepo.create(name: name, category: cat);
          ing = Ingredient(id: id, name: name, category: cat, inStock: false);
        }
        rows.add(
          RecipeIngredientRow(
            ingredient: ing,
            amount: ingRef['amount'] as double,
            unit: ingRef['unit'] as String,
          ),
        );
      }
      if (rows.isNotEmpty) {
        await setIngredients(recipeId, rows);
      }
    }

    final createdRecipes = await getAll();
    if (createdRecipes.isNotEmpty) {
      final now = DateTime.now();
      for (int i = 0; i < 7; i++) {
        final date = now.add(Duration(days: i));
        final dateIso =
            '${date.year.toString().padLeft(4, '0')}-'
            '${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}';
        final bf = createdRecipes.firstWhere((r) => r.mealSlot == 'breakfast');
        final lu = createdRecipes.firstWhere((r) => r.mealSlot == 'lunch');
        final di = createdRecipes.firstWhere((r) => r.mealSlot == 'dinner');
        final sh = createdRecipes.firstWhere((r) => r.mealSlot == 'shake');

        await mealSlotRepo.upsert(
          date: dateIso,
          slot: 'breakfast',
          recipeId: bf.id,
          status: 'accepted',
        );
        await mealSlotRepo.upsert(
          date: dateIso,
          slot: 'lunch',
          recipeId: lu.id,
          status: 'accepted',
        );
        await mealSlotRepo.upsert(
          date: dateIso,
          slot: 'dinner',
          recipeId: di.id,
          status: 'accepted',
        );
        await mealSlotRepo.upsert(
          date: dateIso,
          slot: 'shake',
          recipeId: sh.id,
          status: 'accepted',
        );
      }
    }
  }
}

final recipeRepositoryProvider = Provider<RecipeRepository>(
  (ref) => RecipeRepository(ref.watch(appDatabaseProvider)),
);
