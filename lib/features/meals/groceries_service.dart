import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';

/// Integrates Meal Planning with the Groceries List in the Lists Tab.
class GroceriesService {
  GroceriesService(this._db);

  final AppDatabase _db;

  /// Merges duplicate "Groceries" lists into a single master Groceries collection.
  Future<void> deduplicateGroceriesCollections() async {
    final groceriesCols = await (_db.select(_db.collections)
          ..where(
            (c) =>
                c.template.equals('groceries') |
                c.name.like('Groceries%'),
          ))
        .get();

    if (groceriesCols.length <= 1) return;

    // Pick the primary collection (prefer template == 'groceries' or id == 1)
    groceriesCols.sort((a, b) {
      if (a.template == 'groceries' && b.template != 'groceries') return -1;
      if (b.template == 'groceries' && a.template != 'groceries') return 1;
      return a.id.compareTo(b.id);
    });

    final primaryCol = groceriesCols.first;
    final duplicates = groceriesCols.sublist(1);

    // Get primary items titles
    final primaryItems = await (_db.select(_db.items)
          ..where((i) => i.collectionId.equals(primaryCol.id)))
        .get();
    final existingTitles =
        primaryItems.map((i) => i.title.toLowerCase()).toSet();

    for (final dup in duplicates) {
      final dupItems = await (_db.select(_db.items)
            ..where((i) => i.collectionId.equals(dup.id)))
          .get();

      for (final item in dupItems) {
        if (existingTitles.contains(item.title.toLowerCase())) {
          await (_db.delete(_db.items)..where((i) => i.id.equals(item.id))).go();
        } else {
          await (_db.update(_db.items)..where((i) => i.id.equals(item.id))).write(
            ItemsCompanion(collectionId: Value(primaryCol.id)),
          );
          existingTitles.add(item.title.toLowerCase());
        }
      }

      await (_db.delete(_db.collections)..where((c) => c.id.equals(dup.id))).go();
    }
  }

  /// Retrieves or creates the main Groceries collection in the Lists tab.
  Future<Collection> getOrCreateGroceriesCollection() async {
    await deduplicateGroceriesCollections();
    final existing = await (_db.select(_db.collections)
          ..where(
            (c) =>
                c.template.equals('groceries') |
                c.name.equals('Groceries'),
          ))
        .get();

    if (existing.isNotEmpty) {
      return existing.first;
    }

    final id = await _db.into(_db.collections).insert(
          CollectionsCompanion.insert(
            name: 'Groceries',
            template: 'groceries',
            icon: const Value('shopping_bag'),
          ),
        );
    return (await (_db.select(_db.collections)..where((c) => c.id.equals(id)))
        .getSingle());
  }

  /// Cleans up any catalog ingredient items mistakenly injected into standard Shopping lists.
  Future<void> cleanAccidentalGroceriesFromShoppingLists() async {
    final groceriesCol = await getOrCreateGroceriesCollection();
    final nonGroceriesCols = await (_db.select(_db.collections)
      ..where((c) => c.id.equals(groceriesCol.id).not() & c.name.equals('Groceries').not())).get();

    if (nonGroceriesCols.isEmpty) return;

    final catalog = await (_db.select(_db.ingredients)).get();
    final ingNames = catalog.map((i) => i.name.toLowerCase()).toSet();

    for (final col in nonGroceriesCols) {
      final items = await (_db.select(_db.items)..where((i) => i.collectionId.equals(col.id))).get();
      for (final item in items) {
        if (ingNames.contains(item.title.toLowerCase())) {
          await (_db.delete(_db.items)..where((i) => i.id.equals(item.id))).go();
        }
      }
    }
  }

  /// Deletes duplicate items in all Groceries collections so every item title is unique.
  Future<void> deduplicateGroceriesItems() async {
    await deduplicateGroceriesCollections();

    final groceriesCols = await (_db.select(_db.collections)
          ..where(
            (c) =>
                c.template.equals('groceries') |
                c.name.like('Groceries%'),
          ))
        .get();

    for (final col in groceriesCols) {
      final items = await (_db.select(_db.items)
            ..where((i) => i.collectionId.equals(col.id))
            ..orderBy([(i) => OrderingTerm.asc(i.id)]))
          .get();

      final Set<String> seen = {};
      final List<int> toDelete = [];

      for (final item in items) {
        final norm = item.title.trim().toLowerCase();
        if (seen.contains(norm)) {
          toDelete.add(item.id);
        } else {
          seen.add(norm);
        }
      }

      for (final id in toDelete) {
        await (_db.delete(_db.items)..where((i) => i.id.equals(id))).go();
      }
    }
  }

  /// Syncs/populates all catalog ingredients into a Groceries list in the Lists tab.
  /// If [targetCollectionId] is provided, syncs into that collection; otherwise syncs into default Groceries collection.
  Future<void> syncAllIngredientsToGroceriesList({int? targetCollectionId}) async {
    await deduplicateGroceriesItems();
    await cleanAccidentalGroceriesFromShoppingLists();

    final collection = targetCollectionId != null
        ? ((await (_db.select(_db.collections)..where((c) => c.id.equals(targetCollectionId))).getSingleOrNull()) ??
            await getOrCreateGroceriesCollection())
        : await getOrCreateGroceriesCollection();

    // Ensure we are only syncing into a Groceries collection
    if (collection.template != 'groceries' && collection.name != 'Groceries') return;

    final catalog = await (_db.select(_db.ingredients)).get();
    final existingItems = await (_db.select(_db.items)
          ..where((i) => i.collectionId.equals(collection.id)))
        .get();

    final Map<String, Item> itemByTitle = {};
    for (final item in existingItems) {
      itemByTitle[item.title.trim().toLowerCase()] = item;
    }

    for (final ing in catalog) {
      final ingNameLower = ing.name.trim().toLowerCase();
      final existingItem = itemByTitle[ingNameLower];

      if (existingItem == null) {
        final newId = await _db.into(_db.items).insert(
              ItemsCompanion.insert(
                collectionId: collection.id,
                title: ing.name,
                status: Value(ing.inStock ? 'done' : 'open'),
                imageBefore: Value(ing.image),
              ),
            );
        final insertedItem = await (_db.select(_db.items)..where((i) => i.id.equals(newId))).getSingle();
        itemByTitle[ingNameLower] = insertedItem;
      } else if (ing.image != null && existingItem.imageBefore != ing.image) {
        await (_db.update(_db.items)..where((i) => i.id.equals(existingItem.id)))
            .write(ItemsCompanion(imageBefore: Value(ing.image)));
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
