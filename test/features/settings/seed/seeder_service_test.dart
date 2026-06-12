import 'dart:io';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_planner/core/db/database.dart';
import 'package:personal_planner/core/db/repositories/day_repository.dart';
import 'package:personal_planner/features/finance/repositories/debt_repository.dart';
import 'package:personal_planner/features/fitness/fitness_repository.dart';
import 'package:personal_planner/features/gym/gym_repository.dart';
import 'package:personal_planner/features/habits/habit_repository.dart';
import 'package:personal_planner/features/lists/repositories/collection_repository.dart';
import 'package:personal_planner/features/lists/repositories/item_repository.dart';
import 'package:personal_planner/features/meals/ingredient_repository.dart';
import 'package:personal_planner/features/settings/seed/services/seeder_service.dart';

class CrashingItemRepository extends ItemRepository {
  CrashingItemRepository(super.db);
  int callCount = 0;
  bool shouldCrash = true;

  @override
  Future<int> createItem(ItemsCompanion companion) {
    if (shouldCrash) {
      callCount++;
      if (callCount == 50) {
        throw Exception('Simulated database crash mid-run');
      }
    }
    return super.createItem(companion);
  }
}

void main() {
  late AppDatabase db;
  late DayRepository dayRepo;
  late CollectionRepository collectionRepo;
  late ItemRepository itemRepo;
  late IngredientRepository ingredientRepo;
  late WorkoutPlanRepository planRepo;
  late FitnessRepository fitnessRepo;
  late HabitRepository habitRepo;
  late DebtRepository debtRepo;
  late String seedJson;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dayRepo = DayRepository(db);
    collectionRepo = CollectionRepository(db);
    itemRepo = ItemRepository(db);
    ingredientRepo = IngredientRepository(db);
    planRepo = WorkoutPlanRepository(db);
    fitnessRepo = FitnessRepository(db);
    habitRepo = HabitRepository(db);
    debtRepo = DebtRepository(db);

    // Initial first-launch seeds
    await dayRepo.seedDefaultTagsIfNeeded();
    await planRepo.seedDefaultPlansIfNeeded();
    await collectionRepo.seedDefaultCollectionsIfNeeded();
    await habitRepo.seedDefaultHabitsIfNeeded();

    final file = File('assets/seeds/seed.json');
    seedJson = file.readAsStringSync();
  });

  tearDown(() async {
    await db.close();
  });

  test('run once: inserts and updates correct counts from seed.json', () async {
    final seeder = SeederService(
      db: db,
      dayRepo: dayRepo,
      collectionRepo: collectionRepo,
      itemRepo: itemRepo,
      ingredientRepo: ingredientRepo,
      planRepo: planRepo,
      fitnessRepo: fitnessRepo,
      habitRepo: habitRepo,
      debtRepo: debtRepo,
    );

    final summary = await seeder.run(seedJson);

    expect(summary.alreadySeeded, isFalse);
    expect(summary.warnings, isEmpty);

    // Verify tag counts: 6 default tags updated (colors changed to seed colors), 0 inserted
    expect(summary.tagsInserted, equals(0));
    expect(summary.tagsUpdated, equals(6));

    // Verify collection counts:
    // Pre-seeded: Chores, Shopping, Tech Wishlist, Life Upgrades, University, Personal Projects, Personal Growth, Hobbies, Probable Plans, Job Hunt, Germany, Netherlands, Spain, Australia (total 14).
    // Seed.json has:
    // - Movies & Series (template: media) -> new (1)
    // - Shopping Wishlist (template: shopping) -> new (2)
    // - خرید خونه جدید (template: shopping) -> new (3)
    // - Job Hunt — Austria (template: job, parent: Job Hunt) -> new (4)
    // - Job Hunt — Germany (template: job, parent: Job Hunt) -> new (5)
    // So 5 collections inserted.
    expect(summary.collectionsInserted, equals(5));

    // Verify item counts:
    // Media: 137 items
    // Shopping: 29 (Wishlist) + 71 (خرید خونه جدید) = 100 items
    // Jobs: 4 (Austria) + 2 (Germany) = 6 items
    // Total: 243 items
    expect(summary.itemsInserted, equals(243));
    expect(summary.itemsUpdated, equals(0));
    expect(summary.itemsSkipped, equals(0));

    // Verify ingredients: 47 master ingredients from seed.json
    expect(summary.ingredientsInserted, equals(47));

    // Verify plans: A/B/C updated, 1 new inserted ("راهنما و تغذیه")
    expect(summary.plansInserted, equals(1));
    expect(summary.plansUpdated, equals(3));

    // Verify measurements: 1 inserted
    expect(summary.measurementsInserted, equals(1));

    // Verify goals: 1 inserted ("weight_kg" target 57.0)
    expect(summary.goalsInserted, equals(1));

    // Verify habits: 5 pre-seeded habits updated (matched case-insensitively / fuzzily), 0 inserted
    // default habits: Water, Skincare AM, Skincare PM, Teeth, Reading.
    // seed habits: Drink water (glasses), Brush teeth, Move body (gym or walk), Sleep 7-8 hours, Reading.
    // Skincare AM and Skincare PM are untouched (not in seed).
    // "Drink water (glasses)" matches "Water" (1)
    // "Brush teeth" matches "Teeth" (2)
    // "Reading" matches "Reading" (3)
    // "Move body (gym or walk)" is new (inserted = 1? wait, our summary habit count:
    // Let's check: 3 default habits updated, 2 new habits inserted).
    // Let's verify this expected breakdown:
    // habitsUpdated = 3, habitsInserted = 2
    expect(summary.habitsUpdated, equals(3));
    expect(summary.habitsInserted, equals(2));

    // Verify debts: 1 inserted (Reza debt)
    expect(summary.debtsInserted, equals(1));
  });

  test('run twice: second run is a no-op due to version check', () async {
    final seeder = SeederService(
      db: db,
      dayRepo: dayRepo,
      collectionRepo: collectionRepo,
      itemRepo: itemRepo,
      ingredientRepo: ingredientRepo,
      planRepo: planRepo,
      fitnessRepo: fitnessRepo,
      habitRepo: habitRepo,
      debtRepo: debtRepo,
    );

    // First run
    final summary1 = await seeder.run(seedJson);
    expect(summary1.alreadySeeded, isFalse);

    // Second run
    final summary2 = await seeder.run(seedJson);
    expect(summary2.alreadySeeded, isTrue);
    expect(summary2.itemsInserted, equals(0));
    expect(summary2.itemsUpdated, equals(0));
  });

  test('simulated half-run crash and resume', () async {
    final crashingItemRepo = CrashingItemRepository(db);

    final seeder1 = SeederService(
      db: db,
      dayRepo: dayRepo,
      collectionRepo: collectionRepo,
      itemRepo: crashingItemRepo,
      ingredientRepo: ingredientRepo,
      planRepo: planRepo,
      fitnessRepo: fitnessRepo,
      habitRepo: habitRepo,
      debtRepo: debtRepo,
    );

    // Run seeder with crashing repo, it should crash at 50th item
    var threw = false;
    try {
      await seeder1.run(seedJson);
    } catch (e) {
      threw = true;
      expect(e.toString(), contains('Simulated database crash mid-run'));
    }
    expect(threw, isTrue);

    // Verify that some items were inserted (49 items)
    final allCollections = await collectionRepo.watchAll().first;
    var totalItems = 0;
    for (final c in allCollections) {
      final items = await itemRepo.watchItems(c.id).first;
      totalItems += items.length;
    }
    expect(totalItems, equals(49));

    // Run seeder again with normal item repository, it should resume and complete successfully
    final seeder2 = SeederService(
      db: db,
      dayRepo: dayRepo,
      collectionRepo: collectionRepo,
      itemRepo: itemRepo,
      ingredientRepo: ingredientRepo,
      planRepo: planRepo,
      fitnessRepo: fitnessRepo,
      habitRepo: habitRepo,
      debtRepo: debtRepo,
    );

    final summary2 = await seeder2.run(seedJson);
    expect(summary2.alreadySeeded, isFalse);
    // Out of 243 total items, 49 were already inserted, so 194 inserted on resume, 49 updated/no-op
    expect(summary2.itemsInserted, equals(194));
    expect(summary2.itemsUpdated, equals(49));
    expect(summary2.itemsSkipped, equals(0));

    // Check that we have exactly 243 items in total
    final finalCollections = await collectionRepo.watchAll().first;
    var finalTotalItems = 0;
    for (final c in finalCollections) {
      final items = await itemRepo.watchItems(c.id).first;
      finalTotalItems += items.length;
    }
    expect(finalTotalItems, equals(243));
  });

  test(
    'user pre-existing data remains untouched and natural key collisions are skipped',
    () async {
      // 1. Create a user-created item that does NOT collide
      final simpleCollections = await collectionRepo.watchAll().first;
      final wishlistCol = simpleCollections.firstWhere(
        (c) => c.name == 'Shopping',
      );

      final userItemId = await itemRepo.createItem(
        ItemsCompanion.insert(
          collectionId: wishlistCol.id,
          title: 'User Special Item',
          status: const Value('wanted'),
          description: const Value('User created description'),
        ),
      );

      // 2. Create a user-created item that COLLIDES with a seed item by natural key (title) but has different content
      // We will place this in the "Shopping Wishlist" collection which will be created by the seeder.
      // Wait, the seeder will create the "Shopping Wishlist" collection. We can create it first to mimic user-created collection.
      final shoppingWishlistColId = await collectionRepo.create(
        name: 'Shopping Wishlist',
        template: 'shopping',
      );

      // In seed.json, "Extension Cable" is:
      // { "title": "Extension Cable", "priority": 1, "status": "wanted", "stage": "purchasing-this-month" }
      // We insert "Extension Cable" with different content (e.g. status "bought", priority 3, description "User custom description")
      // since it is created by user, it won't be in the seeded ids list.
      final collidingItemId = await itemRepo.createItem(
        ItemsCompanion.insert(
          collectionId: shoppingWishlistColId,
          title: 'Extension Cable',
          status: const Value('bought'),
          priority: const Value(3),
          description: const Value('User custom description'),
        ),
      );

      // Run the seeder
      final seeder = SeederService(
        db: db,
        dayRepo: dayRepo,
        collectionRepo: collectionRepo,
        itemRepo: itemRepo,
        ingredientRepo: ingredientRepo,
        planRepo: planRepo,
        fitnessRepo: fitnessRepo,
        habitRepo: habitRepo,
        debtRepo: debtRepo,
      );

      final summary = await seeder.run(seedJson);

      // Verify counts: 1 item should be skipped (the colliding "Extension Cable")
      expect(summary.itemsSkipped, equals(1));
      expect(summary.warnings, isNotEmpty);
      expect(
        summary.warnings.first,
        contains("Skipped shopping item 'Extension Cable'"),
      );

      // Verify user's non-colliding item is untouched
      final userItem = await itemRepo.getById(userItemId);
      expect(userItem, isNotNull);
      expect(userItem!.title, equals('User Special Item'));
      expect(userItem.description, equals('User created description'));

      // Verify user's colliding item is untouched and not overwritten
      final collidingItem = await itemRepo.getById(collidingItemId);
      expect(collidingItem, isNotNull);
      expect(collidingItem!.title, equals('Extension Cable'));
      expect(collidingItem.status, equals('bought'));
      expect(collidingItem.priority, equals(3));
      expect(collidingItem.description, equals('User custom description'));
    },
  );
}
