import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/db/database.dart';

/// Amount entry before merging.
class _RawAmount {
  _RawAmount(
    this.ingredientId,
    this.ingredientName,
    this.category,
    this.amount,
    this.unit,
  );
  final int ingredientId;
  final String ingredientName;
  final String? category;
  final double amount;
  final String unit;
}

/// Aggregated shopping line.
class ShoppingLine {
  const ShoppingLine({
    required this.ingredientName,
    required this.category,
    required this.amount,
    required this.unit,
  });
  final String ingredientName;
  final String? category;
  final double amount;
  final String unit;
}

/// Generates or regenerates a "Groceries — week of DATE" shopping collection
/// from accepted meal slots for a given week.
class ShoppingGenerator {
  ShoppingGenerator(this._db);

  final AppDatabase _db;

  /// Creates or updates the shopping collection for [weekStart].
  ///
  /// Idempotent: re-running for the same week updates the existing collection
  /// rather than creating a duplicate.
  Future<int> generateForWeek(DateTime weekStart) async {
    final dates = List.generate(
      7,
      (i) => _fmt(weekStart.add(Duration(days: i))),
    );
    final weekLabel = DateFormat('d MMM yyyy').format(weekStart);
    final collectionName = 'Groceries — week of $weekLabel';

    // Find existing collection for this week (by name) or create one.
    final existing = await (_db.select(
      _db.collections,
    )..where((c) => c.name.equals(collectionName))).get();

    final int collectionId;
    if (existing.isEmpty) {
      collectionId = await _db
          .into(_db.collections)
          .insert(
            CollectionsCompanion.insert(
              name: collectionName,
              template: 'shopping',
            ),
          );
    } else {
      collectionId = existing.first.id;
      // Clear existing items (regeneration).
      await (_db.delete(
        _db.items,
      )..where((i) => i.collectionId.equals(collectionId))).go();
    }

    // Aggregate ingredients across accepted meal slots.
    final lines = await _aggregate(dates);

    // Write items grouped by category.
    final byCategory = <String, List<ShoppingLine>>{};
    for (final line in lines) {
      (byCategory[line.category ?? 'other'] ??= []).add(line);
    }

    for (final entry in byCategory.entries) {
      for (final line in entry.value) {
        final amountStr = line.amount == line.amount.truncate()
            ? line.amount.toInt().toString()
            : line.amount.toStringAsFixed(1);
        await _db
            .into(_db.items)
            .insert(
              ItemsCompanion.insert(
                collectionId: collectionId,
                title: '${line.ingredientName} — $amountStr ${line.unit}',
                meta: Value({'category': entry.key}),
              ),
            );
      }
    }

    return collectionId;
  }

  Future<List<ShoppingLine>> _aggregate(List<String> dates) async {
    // Load accepted slots in range.
    final slots =
        await (_db.select(_db.mealSlots)..where(
              (s) =>
                  s.date.isIn(dates) &
                  (s.status.equals('accepted') | s.status.equals('eaten')),
            ))
            .get();

    if (slots.isEmpty) return [];

    final recipeIds = slots
        .map((s) => s.recipeId)
        .whereType<int>()
        .toSet()
        .toList();
    if (recipeIds.isEmpty) return [];

    // Load recipe_ingredients for those recipes.
    final riRows = await (_db.select(
      _db.recipeIngredients,
    )..where((ri) => ri.recipeId.isIn(recipeIds))).get();

    if (riRows.isEmpty) return [];

    // Load ingredient metadata.
    final ingIds = riRows.map((r) => r.ingredientId).toSet().toList();
    final ings = await (_db.select(
      _db.ingredients,
    )..where((i) => i.id.isIn(ingIds))).get();
    final ingMap = {for (final i in ings) i.id: i};

    // Count how many times each recipe appears (for multi-serving scaling).
    final recipeCounts = <int, int>{};
    for (final s in slots) {
      if (s.recipeId != null) {
        recipeCounts[s.recipeId!] = (recipeCounts[s.recipeId!] ?? 0) + 1;
      }
    }

    // Build raw amounts (one per recipe_ingredient × serving count).
    final rawAmounts = <_RawAmount>[];
    for (final ri in riRows) {
      final ing = ingMap[ri.ingredientId];
      if (ing == null) continue;
      final count = recipeCounts[ri.recipeId] ?? 1;
      rawAmounts.add(
        _RawAmount(ing.id, ing.name, ing.category, ri.amount * count, ri.unit),
      );
    }

    // Sum amounts per ingredient + unit. Different units are listed separately.
    final sumMap = <String, _RawAmount>{}; // key = "ingredientId:unit"
    for (final r in rawAmounts) {
      final key = '${r.ingredientId}:${r.unit}';
      final existing = sumMap[key];
      if (existing == null) {
        sumMap[key] = r;
      } else {
        sumMap[key] = _RawAmount(
          r.ingredientId,
          r.ingredientName,
          r.category,
          existing.amount + r.amount,
          r.unit,
        );
      }
    }

    return sumMap.values
        .map(
          (r) => ShoppingLine(
            ingredientName: r.ingredientName,
            category: r.category,
            amount: r.amount,
            unit: r.unit,
          ),
        )
        .toList()
      ..sort((a, b) {
        final catCmp = (a.category ?? 'zzz').compareTo(b.category ?? 'zzz');
        return catCmp != 0
            ? catCmp
            : a.ingredientName.compareTo(b.ingredientName);
      });
  }

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

final shoppingGeneratorProvider = Provider<ShoppingGenerator>(
  (ref) => ShoppingGenerator(ref.watch(appDatabaseProvider)),
);
