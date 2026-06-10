import 'package:drift/drift.dart';

import '../converters/string_list_converter.dart';

/// Pantry ingredient catalogue.
class Ingredients extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get category =>
      text().nullable()(); // 'produce','dairy','pantry',...
  RealColumn get kcalPer100g => real().nullable()();
  RealColumn get proteinPer100g => real().nullable()();
}

/// Recipe definitions.
class Recipes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get mealSlot => text()(); // 'breakfast'|'lunch'|'dinner'|'any'
  IntColumn get prepMinutes => integer().nullable()();
  TextColumn get tags => text().map(
    const StringListConverter(),
  )(); // JSON: ['quick','high-protein',...]
  TextColumn get instructions => text().nullable()();
  TextColumn get image => text().nullable()();
}

/// Ingredients used in a recipe with amounts.
class RecipeIngredients extends Table {
  IntColumn get recipeId => integer().references(Recipes, #id)();
  IntColumn get ingredientId => integer().references(Ingredients, #id)();
  RealColumn get amount => real()();
  TextColumn get unit => text()(); // 'g','ml','pcs','tbsp'

  @override
  Set<Column<Object>> get primaryKey => {recipeId, ingredientId};
}

/// Planned and accepted meals per day slot.
class MealSlots extends Table {
  TextColumn get date => text()(); // YYYY-MM-DD
  TextColumn get slot =>
      text()(); // 'breakfast'|'lunch'|'dinner'|'post-gym-shake'
  IntColumn get recipeId => integer().nullable().references(Recipes, #id)();
  TextColumn get status => text()(); // 'suggested'|'accepted'|'eaten'|'skipped'

  @override
  Set<Column<Object>> get primaryKey => {date, slot};
}
