import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../../../core/db/repositories/day_repository.dart';
import '../../../finance/repositories/debt_repository.dart';
import '../../../fitness/fitness_repository.dart';
import '../../../gym/gym_repository.dart';
import '../../../habits/habit_repository.dart';
import '../../../lists/repositories/collection_repository.dart';
import '../../../lists/repositories/item_repository.dart';
import '../../../meals/ingredient_repository.dart';
import '../../../meals/meal_slot_repository.dart';
import '../../../meals/recipe_repository.dart';
import '../parser/seed_parser.dart';

class SeedSummary {
  final int tagsInserted;
  final int tagsUpdated;
  final int tagsSkipped;

  final int collectionsInserted;
  final int collectionsUpdated;
  final int collectionsSkipped;

  final int itemsInserted;
  final int itemsUpdated;
  final int itemsSkipped;

  final int ingredientsInserted;
  final int ingredientsUpdated;
  final int ingredientsSkipped;

  final int plansInserted;
  final int plansUpdated;
  final int plansSkipped;

  final int measurementsInserted;
  final int measurementsUpdated;
  final int measurementsSkipped;

  final int goalsInserted;
  final int goalsUpdated;
  final int goalsSkipped;

  final int habitsInserted;
  final int habitsUpdated;
  final int habitsSkipped;

  final int debtsInserted;
  final int debtsUpdated;
  final int debtsSkipped;

  final List<String> warnings;
  final bool alreadySeeded;

  SeedSummary({
    this.tagsInserted = 0,
    this.tagsUpdated = 0,
    this.tagsSkipped = 0,
    this.collectionsInserted = 0,
    this.collectionsUpdated = 0,
    this.collectionsSkipped = 0,
    this.itemsInserted = 0,
    this.itemsUpdated = 0,
    this.itemsSkipped = 0,
    this.ingredientsInserted = 0,
    this.ingredientsUpdated = 0,
    this.ingredientsSkipped = 0,
    this.plansInserted = 0,
    this.plansUpdated = 0,
    this.plansSkipped = 0,
    this.measurementsInserted = 0,
    this.measurementsUpdated = 0,
    this.measurementsSkipped = 0,
    this.goalsInserted = 0,
    this.goalsUpdated = 0,
    this.goalsSkipped = 0,
    this.habitsInserted = 0,
    this.habitsUpdated = 0,
    this.habitsSkipped = 0,
    this.debtsInserted = 0,
    this.debtsUpdated = 0,
    this.debtsSkipped = 0,
    required this.warnings,
    this.alreadySeeded = false,
  });
}

class SeederService {
  final AppDatabase db;
  final DayRepository dayRepo;
  final CollectionRepository collectionRepo;
  final ItemRepository itemRepo;
  final IngredientRepository ingredientRepo;
  final RecipeRepository recipeRepo;
  final MealSlotRepository mealSlotRepo;
  final WorkoutPlanRepository planRepo;
  final FitnessRepository fitnessRepo;
  final HabitRepository habitRepo;
  final DebtRepository debtRepo;

  SeederService({
    required this.db,
    required this.dayRepo,
    required this.collectionRepo,
    required this.itemRepo,
    required this.ingredientRepo,
    required this.recipeRepo,
    required this.mealSlotRepo,
    required this.planRepo,
    required this.fitnessRepo,
    required this.habitRepo,
    required this.debtRepo,
  });

  Future<SeedSummary> run(String seedJsonString) async {
    final parseResult = SeedParser.parse(seedJsonString);
    final warnings = List<String>.from(parseResult.warnings);

    if (parseResult.data == null) {
      return SeedSummary(alreadySeeded: false, warnings: warnings);
    }

    final data = parseResult.data!;

    // 1. Version gate
    final versionRow = await (db.select(
      db.appSettings,
    )..where((s) => s.key.equals('seed_version'))).getSingleOrNull();
    final currentVersion = int.tryParse(versionRow?.value ?? '') ?? 0;

    if (currentVersion >= data.version) {
      final nlInSeed = data.collections.any((c) => c.name.contains('Netherlands') && c.itemsJob.isNotEmpty);
      if (!nlInSeed) {
        return SeedSummary(alreadySeeded: true, warnings: warnings);
      }
      final nlCols = await (db.select(db.collections)..where((c) => c.name.like('%Netherlands%'))).get();
      if (nlCols.isEmpty) {
        return SeedSummary(alreadySeeded: true, warnings: warnings);
      }
      final colIds = nlCols.map((c) => c.id).toList();
      final items = await (db.select(db.items)..where((i) => i.collectionId.isIn(colIds))).get();
      if (items.length >= 50) {
        return SeedSummary(alreadySeeded: true, warnings: warnings);
      }
    }

    // 2. Load seeded record tracker
    final seededMapRow = await (db.select(
      db.appSettings,
    )..where((s) => s.key.equals('seeded_record_ids'))).getSingleOrNull();
    final Map<String, dynamic> seededIds = seededMapRow != null
        ? jsonDecode(seededMapRow.value) as Map<String, dynamic>
        : {};

    final Set<int> seededTagIds = Set<int>.from(
      seededIds['tags'] as List? ?? [],
    );
    final Set<int> seededCollectionIds = Set<int>.from(
      seededIds['collections'] as List? ?? [],
    );
    final Set<int> seededItemIds = Set<int>.from(
      seededIds['items'] as List? ?? [],
    );
    final Set<int> seededGoalIds = Set<int>.from(
      seededIds['goals'] as List? ?? [],
    );
    final Set<int> seededHabitIds = Set<int>.from(
      seededIds['habits'] as List? ?? [],
    );
    final Set<int> seededDebtIds = Set<int>.from(
      seededIds['debts'] as List? ?? [],
    );

    int tagsInserted = 0;
    int tagsUpdated = 0;
    int tagsSkipped = 0;

    int collectionsInserted = 0;
    int collectionsUpdated = 0;
    int collectionsSkipped = 0;

    int itemsInserted = 0;
    int itemsUpdated = 0;
    int itemsSkipped = 0;

    int ingredientsInserted = 0;
    int ingredientsUpdated = 0;
    int ingredientsSkipped = 0;

    int plansInserted = 0;
    int plansUpdated = 0;
    int plansSkipped = 0;

    int measurementsInserted = 0;
    int measurementsUpdated = 0;
    int measurementsSkipped = 0;

    int goalsInserted = 0;
    int goalsUpdated = 0;
    int goalsSkipped = 0;

    int habitsInserted = 0;
    int habitsUpdated = 0;
    int habitsSkipped = 0;

    int debtsInserted = 0;
    int debtsUpdated = 0;
    int debtsSkipped = 0;

    // Seeding in dependency order
    // ── TAGS ──
    final allTags = await dayRepo.getAllTags();
    for (final t in data.tags) {
      final existing = allTags.firstWhereOrNull(
        (tag) => tag.name.toLowerCase() == t.name.toLowerCase(),
      );
      if (existing != null) {
        if (existing.color != t.color) {
          await dayRepo.updateTag(existing.copyWith(color: t.color));
          tagsUpdated++;
        }
      } else {
        final newId = await dayRepo.createTag(
          name: t.name,
          color: t.color,
          kind: t.kind,
          owner: t.owner,
        );
        seededTagIds.add(newId);
        tagsInserted++;
      }
    }

    // ── COLLECTIONS ──
    final allCollections = await collectionRepo.watchAll().first;
    final Map<String, int> collectionIdByName = {
      for (final c in allCollections) c.name.toLowerCase(): c.id,
    };

    for (final col in data.collections) {
      int? parentId;
      if (col.parent != null) {
        parentId = collectionIdByName[col.parent!.toLowerCase()];
        if (parentId == null) {
          warnings.add(
            "Collection '${col.name}': Parent '${col.parent}' not found.",
          );
        }
      }

      final existing = allCollections.firstWhereOrNull(
        (c) =>
            c.name.toLowerCase() == col.name.toLowerCase() &&
            c.parentId == parentId,
      );

      int colId;
      if (existing != null) {
        colId = existing.id;
        collectionIdByName[col.name.toLowerCase()] = colId;
        if (col.coverImage != null || col.icon != null) {
          final updatedCol = existing.copyWith(
            coverImage: Value(col.coverImage ?? existing.coverImage),
            icon: Value(col.icon ?? existing.icon),
          );
          await collectionRepo.update(updatedCol);
        }
        collectionsUpdated++;
      } else {
        colId = await collectionRepo.create(
          name: col.name,
          template: col.template,
          parentId: parentId,
          icon: col.icon,
          coverImage: col.coverImage,
        );
        collectionIdByName[col.name.toLowerCase()] = colId;
        seededCollectionIds.add(colId);
        collectionsInserted++;
      }

      // ── ITEMS ──
      final existingItems = await itemRepo.watchItems(colId).first;

      // A. Media template items
      for (final m in col.itemsMedia) {
        final existingItem = existingItems.firstWhereOrNull(
          (item) => item.title.toLowerCase() == m.title.toLowerCase(),
        );
        final expectedDoneDate = m.status == 'done' ? data.generated : null;

        if (existingItem != null) {
          final isSeederCreated =
              seededItemIds.contains(existingItem.id) ||
              (existingItem.status == m.status &&
                  existingItem.meta?['kind'] == m.kind &&
                  existingItem.doneDate == expectedDoneDate);

          if (isSeederCreated) {
            final updatedItem = existingItem.copyWith(
              status: m.status,
              doneDate: Value(expectedDoneDate),
              meta: Value({'kind': m.kind}),
              imageBefore: Value(m.image ?? existingItem.imageBefore),
            );
            await itemRepo.updateItem(updatedItem);
            seededItemIds.add(existingItem.id);
            itemsUpdated++;
          } else {
            warnings.add(
              "Skipped media item '${m.title}' in collection '${col.name}' because a user-created item with the same title already exists.",
            );
            itemsSkipped++;
          }
        } else {
          final newId = await itemRepo.createItem(
            ItemsCompanion.insert(
              collectionId: colId,
              title: m.title,
              status: Value(m.status),
              doneDate: Value(expectedDoneDate),
              meta: Value({'kind': m.kind}),
              imageBefore: Value(m.image),
            ),
          );
          seededItemIds.add(newId);
          itemsInserted++;
        }
      }

      // B. Shopping template items
      for (final s in col.itemsShopping) {
        final descParts = <String>[];
        if (s.stage != null) descParts.add('Stage: ${s.stage}');
        if (s.costNote != null) descParts.add(s.costNote!);
        final expectedDesc = descParts.isNotEmpty ? descParts.join('\n') : null;

        final existingItem = existingItems.firstWhereOrNull(
          (item) => item.title.toLowerCase() == s.title.toLowerCase(),
        );
        final expectedDoneDate = s.status == 'bought' ? data.generated : null;
        final expectedPriority = s.priority ?? 2;

        if (existingItem != null) {
          final isSeederCreated =
              seededItemIds.contains(existingItem.id) ||
              (existingItem.status == s.status &&
                  existingItem.priority == expectedPriority &&
                  existingItem.plannedCostCents == s.costCents &&
                  existingItem.description == expectedDesc &&
                  existingItem.doneDate == expectedDoneDate);

          if (isSeederCreated) {
            final updatedItem = existingItem.copyWith(
              status: s.status,
              priority: Value(expectedPriority),
              plannedCostCents: Value(s.costCents),
              description: Value(expectedDesc),
              doneDate: Value(expectedDoneDate),
            );
            await itemRepo.updateItem(updatedItem);
            seededItemIds.add(existingItem.id);
            itemsUpdated++;
          } else {
            warnings.add(
              "Skipped shopping item '${s.title}' in collection '${col.name}' because a user-created item with the same title already exists.",
            );
            itemsSkipped++;
          }
        } else {
          final newId = await itemRepo.createItem(
            ItemsCompanion.insert(
              collectionId: colId,
              title: s.title,
              priority: Value(expectedPriority),
              status: Value(s.status),
              plannedCostCents: Value(s.costCents),
              description: Value(expectedDesc),
              doneDate: Value(expectedDoneDate),
            ),
          );
          seededItemIds.add(newId);
          itemsInserted++;
        }
      }

      // C. Job template items
      for (final j in col.itemsJob) {
        final mappedStatus = j.status == 'applied-pending'
            ? 'applied'
            : j.status;
        final existingItem = existingItems.firstWhereOrNull(
          (item) => item.title.toLowerCase() == j.title.toLowerCase(),
        );

        final Map<String, dynamic> jobMeta = {};
        if (j.company != null && j.company!.isNotEmpty) jobMeta['company'] = j.company;
        if (j.category != null && j.category!.isNotEmpty) jobMeta['category'] = j.category;
        if (j.city != null && j.city!.isNotEmpty) jobMeta['city'] = j.city;
        if (j.website != null && j.website!.isNotEmpty) jobMeta['website'] = j.website;
        if (j.linkedin != null && j.linkedin!.isNotEmpty) jobMeta['linkedin'] = j.linkedin;
        final finalMeta = jobMeta.isEmpty ? null : jobMeta;

        if (existingItem != null) {
          final isSeederCreated =
              seededItemIds.contains(existingItem.id) ||
              (existingItem.status == mappedStatus &&
                  existingItem.priority == j.priority &&
                  existingItem.dueDate == j.dueDate &&
                  existingItem.description == j.note);

          if (isSeederCreated) {
            final updatedItem = existingItem.copyWith(
              status: mappedStatus,
              priority: Value(j.priority),
              dueDate: Value(j.dueDate),
              description: Value(j.note),
              meta: Value(finalMeta),
            );
            await itemRepo.updateItem(updatedItem);
            seededItemIds.add(existingItem.id);
            itemsUpdated++;
          } else {
            warnings.add(
              "Skipped job item '${j.title}' in collection '${col.name}' because a user-created item with the same title already exists.",
            );
            itemsSkipped++;
          }
        } else {
          final newId = await itemRepo.createItem(
            ItemsCompanion.insert(
              collectionId: colId,
              title: j.title,
              priority: Value(j.priority),
              status: Value(mappedStatus),
              dueDate: Value(j.dueDate),
              description: Value(j.note),
              meta: Value(finalMeta),
            ),
          );
          seededItemIds.add(newId);
          itemsInserted++;
        }
      }
    }

    // ── INGREDIENTS ──
    for (final ing in data.ingredientsMaster) {
      final existing = await ingredientRepo.getByName(ing.name);
      if (existing != null) {
        if (existing.category != ing.category ||
            (ing.image != null && existing.image != ing.image)) {
          await ingredientRepo.update(
            existing.copyWith(
              category: Value(ing.category),
              image: Value(ing.image ?? existing.image),
            ),
          );
          ingredientsUpdated++;
        }
      } else {
        await ingredientRepo.create(
          name: ing.name,
          category: ing.category,
          image: ing.image,
        );
        ingredientsInserted++;
      }
    }

    // ── RECIPES & MEAL SLOTS ──
    for (final r in data.recipesMaster) {
      final existing = await recipeRepo.search(r.name);
      final exactMatch = existing.firstWhereOrNull(
        (item) => item.name.toLowerCase() == r.name.toLowerCase(),
      );
      if (exactMatch == null) {
        final recipeId = await recipeRepo.create(
          name: r.name,
          mealSlot: r.mealSlot,
          prepMinutes: r.prepMinutes,
          proteinGrams: r.proteinGrams,
          calories: r.calories,
          tags: r.tags,
          instructions: r.instructions,
        );

        final rows = <RecipeIngredientRow>[];
        for (final ingRef in r.ingredients) {
          final ing = await ingredientRepo.getByName(ingRef.name);
          if (ing != null) {
            rows.add(
              RecipeIngredientRow(
                ingredient: ing,
                amount: ingRef.amount,
                unit: ingRef.unit,
              ),
            );
          }
        }
        if (rows.isNotEmpty) {
          await recipeRepo.setIngredients(recipeId, rows);
        }
      }
    }

    final allRecipes = await recipeRepo.getAll();
    if (allRecipes.isNotEmpty) {
      final now = DateTime.now();
      for (int i = 0; i < 7; i++) {
        final date = now.add(Duration(days: i));
        final dateIso =
            '${date.year.toString().padLeft(4, '0')}-'
            '${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}';
        final existingSlots = await mealSlotRepo.getForDate(dateIso);
        if (existingSlots.isEmpty) {
          final bf =
              allRecipes.firstWhereOrNull((r) => r.mealSlot == 'breakfast') ??
              allRecipes[0];
          final lu =
              allRecipes.firstWhereOrNull((r) => r.mealSlot == 'lunch') ??
              allRecipes[1 % allRecipes.length];
          final di =
              allRecipes.firstWhereOrNull((r) => r.mealSlot == 'dinner') ??
              allRecipes[2 % allRecipes.length];
          final sh =
              allRecipes.firstWhereOrNull((r) => r.mealSlot == 'shake') ??
              allRecipes[3 % allRecipes.length];

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

    // ── WORKOUT PLANS ──
    final allPlans = await planRepo.watchAll().first;
    for (final p in data.workoutPlans) {
      final existing = allPlans.firstWhereOrNull(
        (plan) => plan.name.toLowerCase() == p.name.toLowerCase(),
      );
      if (existing != null) {
        await planRepo.update(existing.copyWith(content: p.content));
        plansUpdated++;
      } else {
        await planRepo.create(name: p.name, content: p.content);
        plansInserted++;
      }
    }

    // ── FITNESS MEASUREMENT ──
    final measurement = data.fitness.initialMeasurement;
    if (measurement != null) {
      final existingMeas = await fitnessRepo.getMeasurements();
      if (existingMeas.isEmpty) {
        await fitnessRepo.createMeasurement(
          MeasurementsCompanion.insert(
            date: measurement.date,
            weightKg: Value(measurement.weightKg),
          ),
        );
        measurementsInserted++;
      } else {
        measurementsSkipped++;
      }
    }

    // ── SPORT ACTIVITIES ──
    for (final act in data.sportActivities) {
      final existingOnDate = await (db.select(db.sportActivities)
            ..where(
              (s) =>
                  s.date.equals(act.date) &
                  s.durationMin.equals(act.durationMin),
            ))
          .get();

      if (existingOnDate.isNotEmpty) {
        final primary = existingOnDate.first;
        await (db.update(db.sportActivities)
              ..where((s) => s.id.equals(primary.id)))
            .write(
          SportActivitiesCompanion(
            activityType: Value(act.activityType),
            calories: Value(act.calories),
            notes: Value(act.notes),
          ),
        );
        for (var i = 1; i < existingOnDate.length; i++) {
          await (db.delete(db.sportActivities)
                ..where((s) => s.id.equals(existingOnDate[i].id)))
              .go();
        }
      } else {
        await db.into(db.sportActivities).insert(
              SportActivitiesCompanion.insert(
                date: act.date,
                activityType: act.activityType,
                durationMin: act.durationMin,
                calories: Value(act.calories),
                notes: Value(act.notes),
              ),
            );
      }
    }

    // ── PERIOD LOGS ──
    for (final p in data.periodLogs) {
      final existing = await (db.select(db.periodLogs)
            ..where((log) => log.startDate.equals(p.startDate)))
          .get();
      if (existing.isEmpty) {
        await db.into(db.periodLogs).insert(
              PeriodLogsCompanion.insert(
                startDate: p.startDate,
                durationDays: Value(p.durationDays),
              ),
            );
      } else {
        await (db.update(db.periodLogs)
              ..where((log) => log.startDate.equals(p.startDate)))
            .write(
          PeriodLogsCompanion(
            durationDays: Value(p.durationDays),
          ),
        );
      }
    }

    // ── FITNESS GOALS ──
    final allGoals = await fitnessRepo.getGoals();
    for (final g in data.fitness.goals) {
      final existing = allGoals.firstWhereOrNull(
        (goal) => goal.metric.toLowerCase() == g.metric.toLowerCase(),
      );
      final expectedDirection = g.metric == 'weight_kg' ? 'down' : 'up';

      if (existing != null) {
        final isSeederCreated =
            seededGoalIds.contains(existing.id) ||
            (existing.target == g.target &&
                existing.deadline == g.deadline &&
                existing.direction == expectedDirection);

        if (isSeederCreated) {
          await fitnessRepo.updateGoal(
            existing.copyWith(
              target: g.target,
              deadline: Value(g.deadline),
              direction: expectedDirection,
            ),
          );
          seededGoalIds.add(existing.id);
          goalsUpdated++;
        } else {
          warnings.add(
            "Skipped fitness goal for metric '${g.metric}' because a user-created goal already exists.",
          );
          goalsSkipped++;
        }
      } else {
        final newId = await fitnessRepo.createGoal(
          FitnessGoalsCompanion.insert(
            metric: g.metric,
            target: g.target,
            deadline: Value(g.deadline),
            direction: Value(expectedDirection),
          ),
        );
        seededGoalIds.add(newId);
        goalsInserted++;
      }
    }

    // ── HABITS ──
    final allHabits = await habitRepo.watchAllHabits().first;
    for (final h in data.habits) {
      final existing = _findMatchingHabit(h.name, allHabits);
      if (existing != null) {
        final updated = existing.copyWith(
          name: h.name,
          targetPerDay: h.targetPerDay,
          reminderTimes: Value(h.reminderTimes),
        );
        await habitRepo.updateHabit(updated);
        habitsUpdated++;
      } else {
        final newId = await habitRepo.createHabit(
          HabitsCompanion.insert(
            name: h.name,
            targetPerDay: Value(h.targetPerDay),
            reminderTimes: Value(h.reminderTimes),
          ),
        );
        seededHabitIds.add(newId);
        habitsInserted++;
      }
    }

    // ── DEBTS ──
    final activeDebts = await debtRepo.watchAll().first;
    final settledDebts = await debtRepo.watchSettled().first;
    final allDebts = [...activeDebts, ...settledDebts];

    for (final d in data.debts) {
      final existing = allDebts.firstWhereOrNull(
        (debt) =>
            debt.person.toLowerCase() == d.person.toLowerCase() &&
            debt.direction == d.direction,
      );

      if (existing != null) {
        final isSeederCreated =
            seededDebtIds.contains(existing.id) ||
            (existing.amountCents == d.amountCents && existing.note == d.note);

        if (isSeederCreated) {
          await debtRepo.update(
            existing.copyWith(amountCents: d.amountCents, note: Value(d.note)),
          );
          seededDebtIds.add(existing.id);
          debtsUpdated++;
        } else {
          warnings.add(
            "Skipped debt for '${d.person}' (${d.direction}) because a user-created debt already exists.",
          );
          debtsSkipped++;
        }
      } else {
        final newId = await debtRepo.create(
          DebtsCompanion.insert(
            person: d.person,
            amountCents: d.amountCents,
            direction: d.direction,
            note: Value(d.note),
            settled: const Value(false),
          ),
        );
        seededDebtIds.add(newId);
        debtsInserted++;
      }
    }

    // ── RECURRING TRANSACTIONS ──
    for (final r in data.recurringTransactions) {
      final existing = await (db.select(db.recurringTransactions)
            ..where((t) => t.name.equals(r.name)))
          .get();
      if (existing.isEmpty) {
        await db.into(db.recurringTransactions).insert(
              RecurringTransactionsCompanion.insert(
                name: r.name,
                amountCents: r.amountCents,
                direction: r.direction,
                dayOfMonth: r.dayOfMonth,
                startMonth: r.startMonth,
                category: r.category,
                active: const Value(true),
              ),
            );
      } else {
        await (db.update(db.recurringTransactions)
              ..where((t) => t.name.equals(r.name)))
            .write(
          RecurringTransactionsCompanion(
            amountCents: Value(r.amountCents),
            direction: Value(r.direction),
            dayOfMonth: Value(r.dayOfMonth),
            startMonth: Value(r.startMonth),
            category: Value(r.category),
          ),
        );
      }
    }

    // ── INITIAL TRANSACTIONS ──
    for (final tx in data.initialTransactions) {
      final noteVal = tx.note ?? '';
      final existing = await (db.select(db.transactions)
            ..where((t) => t.note.equals(noteVal)))
          .get();
      if (existing.isEmpty) {
        await db.into(db.transactions).insert(
              TransactionsCompanion.insert(
                date: tx.date,
                amountCents: tx.amountCents,
                direction: tx.direction,
                status: tx.status,
                category: tx.category,
                note: Value(tx.note),
              ),
            );
      } else {
        await (db.update(db.transactions)
              ..where((t) => t.note.equals(noteVal)))
            .write(
          TransactionsCompanion(
            amountCents: Value(tx.amountCents),
            direction: Value(tx.direction),
            status: Value(tx.status),
            category: Value(tx.category),
          ),
        );
      }
    }

    // ── GLOBAL DEDUPLICATION ──
    await itemRepo.deduplicateAllItems();

    // ── PERSIST TRACKER STATE ──
    final Map<String, dynamic> updatedMap = {
      'tags': seededTagIds.toList(),
      'collections': seededCollectionIds.toList(),
      'items': seededItemIds.toList(),
      'goals': seededGoalIds.toList(),
      'habits': seededHabitIds.toList(),
      'debts': seededDebtIds.toList(),
    };
    await db
        .into(db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: 'seeded_record_ids',
            value: jsonEncode(updatedMap),
          ),
        );

    await db
        .into(db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: 'seed_version',
            value: data.version.toString(),
          ),
        );

    return SeedSummary(
      tagsInserted: tagsInserted,
      tagsUpdated: tagsUpdated,
      tagsSkipped: tagsSkipped,
      collectionsInserted: collectionsInserted,
      collectionsUpdated: collectionsUpdated,
      collectionsSkipped: collectionsSkipped,
      itemsInserted: itemsInserted,
      itemsUpdated: itemsUpdated,
      itemsSkipped: itemsSkipped,
      ingredientsInserted: ingredientsInserted,
      ingredientsUpdated: ingredientsUpdated,
      ingredientsSkipped: ingredientsSkipped,
      plansInserted: plansInserted,
      plansUpdated: plansUpdated,
      plansSkipped: plansSkipped,
      measurementsInserted: measurementsInserted,
      measurementsUpdated: measurementsUpdated,
      measurementsSkipped: measurementsSkipped,
      goalsInserted: goalsInserted,
      goalsUpdated: goalsUpdated,
      goalsSkipped: goalsSkipped,
      habitsInserted: habitsInserted,
      habitsUpdated: habitsUpdated,
      habitsSkipped: habitsSkipped,
      debtsInserted: debtsInserted,
      debtsUpdated: debtsUpdated,
      debtsSkipped: debtsSkipped,
      warnings: warnings,
      alreadySeeded: false,
    );
  }

  Habit? _findMatchingHabit(String seedName, List<Habit> dbHabits) {
    final sLower = seedName.toLowerCase();
    if (sLower.contains('water')) {
      final match = dbHabits.firstWhereOrNull(
        (h) => h.name.toLowerCase().contains('water'),
      );
      if (match != null) return match;
    }
    if (sLower.contains('teeth') || sLower.contains('tooth')) {
      final match = dbHabits.firstWhereOrNull(
        (h) =>
            h.name.toLowerCase().contains('teeth') ||
            h.name.toLowerCase().contains('tooth'),
      );
      if (match != null) return match;
    }
    if (sLower.contains('skincare')) {
      if (sLower.contains('am')) {
        final match = dbHabits.firstWhereOrNull(
          (h) =>
              h.name.toLowerCase().contains('skincare') &&
              h.name.toLowerCase().contains('am'),
        );
        if (match != null) return match;
      }
      if (sLower.contains('pm')) {
        final match = dbHabits.firstWhereOrNull(
          (h) =>
              h.name.toLowerCase().contains('skincare') &&
              h.name.toLowerCase().contains('pm'),
        );
        if (match != null) return match;
      }
      final match = dbHabits.firstWhereOrNull(
        (h) => h.name.toLowerCase().contains('skincare'),
      );
      if (match != null) return match;
    }
    if (sLower.contains('reading')) {
      final match = dbHabits.firstWhereOrNull(
        (h) => h.name.toLowerCase().contains('reading'),
      );
      if (match != null) return match;
    }
    return dbHabits.firstWhereOrNull((h) => h.name.toLowerCase() == sLower);
  }
}

final seederServiceProvider = Provider<SeederService>((ref) {
  return SeederService(
    db: ref.watch(appDatabaseProvider),
    dayRepo: ref.watch(dayRepositoryProvider),
    collectionRepo: ref.watch(collectionRepositoryProvider),
    itemRepo: ref.watch(itemRepositoryProvider),
    ingredientRepo: ref.watch(ingredientRepositoryProvider),
    recipeRepo: ref.watch(recipeRepositoryProvider),
    mealSlotRepo: ref.watch(mealSlotRepositoryProvider),
    planRepo: ref.watch(workoutPlanRepositoryProvider),
    fitnessRepo: ref.watch(fitnessRepositoryProvider),
    habitRepo: ref.watch(habitRepositoryProvider),
    debtRepo: ref.watch(debtRepositoryProvider),
  );
});

final debugSeedingEnabledProvider = Provider<bool>((ref) => kDebugMode);
