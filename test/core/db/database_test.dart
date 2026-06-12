import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_planner/core/db/database.dart';

AppDatabase _openTestDb() => AppDatabase(NativeDatabase.memory());

void main() {
  late AppDatabase db;

  setUp(() => db = _openTestDb());
  tearDown(() => db.close());

  // ── Core day layer ──────────────────────────────────────────────

  test('tags CRUD', () async {
    final id = await db
        .into(db.tags)
        .insert(
          TagsCompanion.insert(
            name: 'linz',
            color: '#F5C518',
            kind: 'location',
          ),
        );
    final row = await (db.select(
      db.tags,
    )..where((t) => t.id.equals(id))).getSingle();
    expect(row.name, 'linz');
    expect(row.color, '#F5C518');
    expect(row.kind, 'location');
    expect(row.owner, 'me');
  });

  test('day_tags CRUD', () async {
    final tagId = await db
        .into(db.tags)
        .insert(
          TagsCompanion.insert(name: 'gym', color: '#FF0000', kind: 'activity'),
        );
    await db
        .into(db.dayTags)
        .insert(DayTagsCompanion.insert(date: '2026-01-15', tagId: tagId));
    final rows = await db.select(db.dayTags).get();
    expect(rows.length, 1);
    expect(rows.first.source, 'manual');
  });

  test('events CRUD', () async {
    final id = await db
        .into(db.events)
        .insert(
          EventsCompanion.insert(
            title: 'Doctor',
            date: '2026-01-20',
            category: 'appointment',
          ),
        );
    final row = await (db.select(
      db.events,
    )..where((e) => e.id.equals(id))).getSingle();
    expect(row.title, 'Doctor');
    expect(row.owner, 'me');
  });

  test('trips CRUD with JSON type converters', () async {
    final id = await db
        .into(db.trips)
        .insert(
          TripsCompanion.insert(
            title: 'Vienna',
            status: 'final',
            links: const Value(['https://example.com', 'https://other.com']),
            meta: const Value({'hotel': 'Grand', 'budget': 200}),
          ),
        );
    final row = await (db.select(
      db.trips,
    )..where((t) => t.id.equals(id))).getSingle();
    expect(row.links, ['https://example.com', 'https://other.com']);
    expect(row.meta!['hotel'], 'Grand');
  });

  test('reminders CRUD with JSON notifyRule', () async {
    final id = await db
        .into(db.reminders)
        .insert(
          RemindersCompanion.insert(
            title: 'Visa',
            windowStart: '2026-02-01',
            notifyRule: const Value({'days_before': 7, 'time': '09:00'}),
          ),
        );
    final row = await (db.select(
      db.reminders,
    )..where((r) => r.id.equals(id))).getSingle();
    expect(row.priority, 2);
    expect(row.status, 'open');
    expect(row.notifyRule!['days_before'], 7);
  });

  // ── List engine ─────────────────────────────────────────────────

  test('collections, items, subtasks CRUD', () async {
    final colId = await db
        .into(db.collections)
        .insert(
          CollectionsCompanion.insert(name: 'Shopping', template: 'shopping'),
        );
    final itemId = await db
        .into(db.items)
        .insert(
          ItemsCompanion.insert(
            collectionId: colId,
            title: 'Apples',
            meta: const Value({'shop_url': 'https://shop.example.com'}),
          ),
        );
    await db
        .into(db.subtasks)
        .insert(SubtasksCompanion.insert(itemId: itemId, title: 'Red variety'));

    final col = await (db.select(
      db.collections,
    )..where((c) => c.id.equals(colId))).getSingle();
    expect(col.template, 'shopping');
    expect(col.archived, false);

    final item = await (db.select(
      db.items,
    )..where((i) => i.id.equals(itemId))).getSingle();
    expect(item.title, 'Apples');
    expect(item.meta!['shop_url'], 'https://shop.example.com');

    final subs = await (db.select(
      db.subtasks,
    )..where((s) => s.itemId.equals(itemId))).get();
    expect(subs.length, 1);
    expect(subs.first.title, 'Red variety');
  });

  // ── Finance ──────────────────────────────────────────────────────

  test('transactions CRUD', () async {
    final id = await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            date: '2026-01-10',
            amountCents: 1200,
            direction: 'out',
            status: 'actual',
            category: 'food',
          ),
        );
    final row = await (db.select(
      db.transactions,
    )..where((t) => t.id.equals(id))).getSingle();
    expect(row.amountCents, 1200);
  });

  test('recurring_transactions CRUD', () async {
    final id = await db
        .into(db.recurringTransactions)
        .insert(
          RecurringTransactionsCompanion.insert(
            name: 'Rent',
            amountCents: 70000,
            direction: 'out',
            dayOfMonth: 1,
            startMonth: '2026-01',
            category: 'rent',
          ),
        );
    final row = await (db.select(
      db.recurringTransactions,
    )..where((r) => r.id.equals(id))).getSingle();
    expect(row.name, 'Rent');
    expect(row.active, true);
  });

  test('debts CRUD', () async {
    final id = await db
        .into(db.debts)
        .insert(
          DebtsCompanion.insert(
            person: 'Alice',
            amountCents: 5000,
            direction: 'owes_me',
          ),
        );
    final row = await (db.select(
      db.debts,
    )..where((d) => d.id.equals(id))).getSingle();
    expect(row.person, 'Alice');
    expect(row.settled, false);
  });

  // ── Meals ────────────────────────────────────────────────────────

  test('ingredients, recipes, recipe_ingredients, meal_slots CRUD', () async {
    final ingId = await db
        .into(db.ingredients)
        .insert(
          IngredientsCompanion.insert(
            name: 'Chicken breast',
            category: const Value('protein'),
          ),
        );
    final recId = await db
        .into(db.recipes)
        .insert(
          RecipesCompanion.insert(
            name: 'Grilled Chicken',
            mealSlot: 'dinner',
            tags: ['high-protein', 'quick'],
          ),
        );
    await db
        .into(db.recipeIngredients)
        .insert(
          RecipeIngredientsCompanion.insert(
            recipeId: recId,
            ingredientId: ingId,
            amount: 200,
            unit: 'g',
          ),
        );
    await db
        .into(db.mealSlots)
        .insert(
          MealSlotsCompanion.insert(
            date: '2026-01-15',
            slot: 'dinner',
            recipeId: Value(recId),
            status: 'accepted',
          ),
        );

    final recipe = await (db.select(
      db.recipes,
    )..where((r) => r.id.equals(recId))).getSingle();
    expect(recipe.tags, contains('high-protein'));

    final ri = await (db.select(
      db.recipeIngredients,
    )..where((ri) => ri.recipeId.equals(recId))).getSingle();
    expect(ri.amount, 200);

    final slot = await (db.select(
      db.mealSlots,
    )..where((s) => s.slot.equals('dinner'))).getSingle();
    expect(slot.status, 'accepted');
  });

  // ── Fitness ──────────────────────────────────────────────────────

  test('workout_plans, gym_sessions CRUD', () async {
    final planId = await db
        .into(db.workoutPlans)
        .insert(
          WorkoutPlansCompanion.insert(
            name: 'Plan A',
            content: '## Plan A\n- Squats',
          ),
        );
    final sessId = await db
        .into(db.gymSessions)
        .insert(
          GymSessionsCompanion.insert(
            date: '2026-01-15',
            planId: Value(planId),
            status: 'done',
          ),
        );
    final sess = await (db.select(
      db.gymSessions,
    )..where((s) => s.id.equals(sessId))).getSingle();
    expect(sess.status, 'done');
  });

  test('measurements CRUD with JSON converters', () async {
    final id = await db
        .into(db.measurements)
        .insert(
          MeasurementsCompanion.insert(
            date: '2026-01-15',
            weightKg: const Value(62.5),
            fields: const Value({'waist_cm': 70.0, 'hip_cm': 95.0}),
            photos: const Value(['images/photo1.jpg']),
          ),
        );
    final row = await (db.select(
      db.measurements,
    )..where((m) => m.id.equals(id))).getSingle();
    expect(row.weightKg, 62.5);
    expect(row.fields!['waist_cm'], 70.0);
    expect(row.photos, ['images/photo1.jpg']);
  });

  test('fitness_goals CRUD', () async {
    final id = await db
        .into(db.fitnessGoals)
        .insert(
          FitnessGoalsCompanion.insert(metric: 'weight_kg', target: 58.0),
        );
    final row = await (db.select(
      db.fitnessGoals,
    )..where((g) => g.id.equals(id))).getSingle();
    expect(row.target, 58.0);
  });

  test('habits, habit_logs CRUD with JSON reminderTimes', () async {
    final habitId = await db
        .into(db.habits)
        .insert(
          HabitsCompanion.insert(
            name: 'Water',
            targetPerDay: const Value(8),
            reminderTimes: const Value(['09:00', '13:00', '17:00', '21:00']),
          ),
        );
    await db
        .into(db.habitLogs)
        .insert(
          HabitLogsCompanion.insert(
            habitId: habitId,
            date: '2026-01-15',
            count: const Value(3),
          ),
        );

    final habit = await (db.select(
      db.habits,
    )..where((h) => h.id.equals(habitId))).getSingle();
    expect(habit.reminderTimes, hasLength(4));
    expect(habit.reminderTimes!.first, '09:00');

    final log = await (db.select(
      db.habitLogs,
    )..where((l) => l.habitId.equals(habitId))).getSingle();
    expect(log.count, 3);
  });

  // ── Wellbeing ────────────────────────────────────────────────────

  test('wellbeing_actions, wellbeing_logs CRUD', () async {
    final actionId = await db
        .into(db.wellbeingActions)
        .insert(WellbeingActionsCompanion.insert(name: 'Meditation'));
    await db
        .into(db.wellbeingLogs)
        .insert(
          WellbeingLogsCompanion.insert(date: '2026-01-15', actionId: actionId),
        );
    final logs = await db.select(db.wellbeingLogs).get();
    expect(logs.length, 1);
  });

  // ── Work ──────────────────────────────────────────────────────────

  test('work_contexts, time_entries CRUD', () async {
    final ctxId = await db
        .into(db.workContexts)
        .insert(WorkContextsCompanion.insert(name: 'FreshFX'));
    final entryId = await db
        .into(db.timeEntries)
        .insert(
          TimeEntriesCompanion.insert(
            contextId: ctxId,
            date: '2026-01-15',
            minutes: 90,
          ),
        );
    final entry = await (db.select(
      db.timeEntries,
    )..where((e) => e.id.equals(entryId))).getSingle();
    expect(entry.minutes, 90);
  });

  // ── Social ────────────────────────────────────────────────────────

  test('social_accounts, social_logs CRUD', () async {
    final accId = await db
        .into(db.socialAccounts)
        .insert(SocialAccountsCompanion.insert(platform: 'Instagram'));
    final logId = await db
        .into(db.socialLogs)
        .insert(
          SocialLogsCompanion.insert(
            accountId: accId,
            date: '2026-01-15',
            activity: const Value('post'),
          ),
        );
    final log = await (db.select(
      db.socialLogs,
    )..where((l) => l.id.equals(logId))).getSingle();
    expect(log.activity, 'post');
  });

  // ── Settings ──────────────────────────────────────────────────────

  test('app_settings CRUD', () async {
    await db
        .into(db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(key: 'calendar_filter', value: 'all'),
        );
    final row = await (db.select(
      db.appSettings,
    )..where((s) => s.key.equals('calendar_filter'))).getSingle();
    expect(row.value, 'all');
  });

  // ── Type-converter round-trip ─────────────────────────────────────

  test('StringListConverter round-trips correctly', () async {
    final id = await db
        .into(db.recipes)
        .insert(
          RecipesCompanion.insert(
            name: 'Test',
            mealSlot: 'any',
            tags: ['tag1', 'tag2', 'tag-with-dash'],
          ),
        );
    final row = await (db.select(
      db.recipes,
    )..where((r) => r.id.equals(id))).getSingle();
    expect(row.tags, ['tag1', 'tag2', 'tag-with-dash']);
  });

  test('JsonMapConverter round-trips correctly', () async {
    final id = await db
        .into(db.trips)
        .insert(
          TripsCompanion.insert(
            title: 'Round-trip test',
            status: 'probable',
            meta: const Value({
              'nested': 1,
              'list': [1, 2],
            }),
          ),
        );
    final row = await (db.select(
      db.trips,
    )..where((t) => t.id.equals(id))).getSingle();
    expect(row.meta!['nested'], 1);
    expect(row.meta!['list'], [1, 2]);
  });

  test('NullAwareTypeConverter returns null when column is null', () async {
    final id = await db
        .into(db.trips)
        .insert(TripsCompanion.insert(title: 'No links', status: 'probable'));
    final row = await (db.select(
      db.trips,
    )..where((t) => t.id.equals(id))).getSingle();
    expect(row.links, isNull);
    expect(row.meta, isNull);
  });
}
