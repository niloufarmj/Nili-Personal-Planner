import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';

/// Integrates Meal Planning with the Groceries List in the Lists Tab.
class GroceriesService {
  GroceriesService(this._db);

  final AppDatabase _db;

  /// Retrieves or creates the main Groceries collection in the Lists tab.
  Future<Collection> getOrCreateGroceriesCollection() async {
    final existing = await (_db.select(_db.collections)
          ..where(
            (c) =>
                c.template.equals('shopping') |
                c.name.equals('Groceries') |
                c.name.equals('Shopping'),
          ))
        .get();

    if (existing.isNotEmpty) {
      return existing.first;
    }

    final id = await _db.into(_db.collections).insert(
          CollectionsCompanion.insert(
            name: 'Groceries',
            template: 'shopping',
            icon: const Value('shopping_bag'),
          ),
        );
    return (await (_db.select(_db.collections)..where((c) => c.id.equals(id)))
        .getSingle());
  }

  /// Syncs/populates all catalog ingredients into a Groceries list in the Lists tab.
  /// If [targetCollectionId] is provided, syncs into that collection; otherwise syncs into default Groceries collection.
  Future<void> syncAllIngredientsToGroceriesList({int? targetCollectionId}) async {
    final collection = targetCollectionId != null
        ? ((await (_db.select(_db.collections)..where((c) => c.id.equals(targetCollectionId))).getSingleOrNull()) ??
            await getOrCreateGroceriesCollection())
        : await getOrCreateGroceriesCollection();

    final catalog = await (_db.select(_db.ingredients)).get();
    final existingItems = await (_db.select(_db.items)
          ..where((i) => i.collectionId.equals(collection.id)))
        .get();

    for (final ing in catalog) {
      final ingNameLower = ing.name.toLowerCase();
      final exists = existingItems.any((i) {
        final titleLower = i.title.toLowerCase();
        return titleLower.contains(ingNameLower) || ingNameLower.contains(titleLower);
      });
      if (!exists) {
        await _db.into(_db.items).insert(
              ItemsCompanion.insert(
                collectionId: collection.id,
                title: ing.name,
                status: Value(ing.inStock ? 'done' : 'open'),
              ),
            );
      }
    }
  }

  /// Returns a stream of missing ingredient names for a given [recipeId].
  /// Checked items (`status == 'done'`) in the Groceries collection count as "In Stock".
  /// Unchecked items (`status == 'open'`) or unlisted items count as "Need to Buy".
  Future<List<String>> getMissingIngredientsForRecipe(int recipeId) async {
    final collection = await getOrCreateGroceriesCollection();
    final items = await (_db.select(_db.items)
          ..where((i) => i.collectionId.equals(collection.id)))
        .get();

    final recipeRows = await (_db.select(_db.recipeIngredients).join([
      innerJoin(
        _db.ingredients,
        _db.ingredients.id.equalsExp(_db.recipeIngredients.ingredientId),
      ),
    ])
          ..where(_db.recipeIngredients.recipeId.equals(recipeId)))
        .get();

    final missingNames = <String>[];
    for (final row in recipeRows) {
      final ingName = row.readTable(_db.ingredients).name;
      final ingNameLower = ingName.toLowerCase();

      final matchingItem = items.firstWhere(
        (item) {
          final itemTitleLower = item.title.toLowerCase();
          return itemTitleLower.contains(ingNameLower) ||
              ingNameLower.contains(itemTitleLower);
        },
        orElse: () => Item(
          id: -1,
          collectionId: collection.id,
          title: '',
          status: 'open',
          description: null,
          priority: null,
          dueDate: null,
          doneDate: null,
          plannedCostCents: null,
          recurrence: null,
          imageBefore: null,
          imageAfter: null,
          meta: null,
        ),
      );

      if (matchingItem.id == -1 || matchingItem.status != 'done') {
        missingNames.add(ingName);
      }
    }

    return missingNames;
  }

  /// Ensures that any missing ingredients for a recipe exist in the Groceries list in the Lists tab.
  Future<void> ensureMissingIngredientsInGroceriesList(
    List<String> missingNames,
  ) async {
    final collection = await getOrCreateGroceriesCollection();
    final existingItems = await (_db.select(_db.items)
          ..where((i) => i.collectionId.equals(collection.id)))
        .get();

    for (final name in missingNames) {
      final nameLower = name.toLowerCase();
      final exists = existingItems.any((i) {
        final titleLower = i.title.toLowerCase();
        return titleLower.contains(nameLower) || nameLower.contains(titleLower);
      });
      if (!exists) {
        await _db.into(_db.items).insert(
              ItemsCompanion.insert(
                collectionId: collection.id,
                title: name,
                status: const Value('open'),
              ),
            );
      }
    }
  }

  /// Toggles an item in the Groceries list to 'done' (have it) or 'open' (need to buy).
  Future<void> toggleGroceryItemStock(String itemName, bool haveIt) async {
    final collection = await getOrCreateGroceriesCollection();
    final nameLower = itemName.toLowerCase();

    final items = await (_db.select(_db.items)
          ..where((i) => i.collectionId.equals(collection.id)))
        .get();

    final matchingItem = items.cast<Item?>().firstWhere(
          (i) =>
              i != null &&
              (i.title.toLowerCase().contains(nameLower) ||
                  nameLower.contains(i.title.toLowerCase())),
          orElse: () => null,
        );

    if (matchingItem != null) {
      await (_db.update(_db.items)..where((i) => i.id.equals(matchingItem.id)))
          .write(
        ItemsCompanion(
          status: Value(haveIt ? 'done' : 'open'),
        ),
      );
    } else {
      await _db.into(_db.items).insert(
            ItemsCompanion.insert(
              collectionId: collection.id,
              title: itemName,
              status: Value(haveIt ? 'done' : 'open'),
            ),
          );
    }
  }
}

final groceriesServiceProvider = Provider<GroceriesService>(
  (ref) => GroceriesService(ref.watch(appDatabaseProvider)),
);
