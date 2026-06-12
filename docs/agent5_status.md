# Agent 5 — Planning & Meals: Status

Branch: `feat/planning-meals`

## Completed

### 1. TripRepository (`lib/features/trips/`)
- Full CRUD with status flow: `idea → probable → final → done`
- Auto-writes `travel` day-tag on finalise; removes it on un-finalise
- Packing list creation (named collection linked to trip)
- Budget transaction helpers

### 2. Trip UI (`lib/features/trips/`)
- `TravelPlannerScreen` — filterable list of trips
- `TripDetailScreen` — shows status, dates, packing list, budget entries
- `TripEditSheet` — bottom sheet for create/edit

### 3. Reminders (`lib/features/reminders/`)
- `ReminderRepository` — CRUD, `isActiveOn` pure helper, window-active filter
- `NotificationService.cancel` now guards on `_initialized` (safe in tests)
- `RemindersScreen` — list + create/edit sheet

### 4. Partner Schedule (`lib/features/partner/`)
- `PartnerRepository` — Reza tag CRUD, partner event overlay
- `PartnerScreen` — read-only view of partner's weekly schedule

### 5. ConflictEngine (`lib/core/conflicts/`)
- `ConflictFeed` interface + `ConflictEngine` implementation
- **R1** `TravelGymRule` — gym session on travel day → skip/move actions
- **R2** `TravelEventRule` — personal event on final trip day → info card
- **R3** `TravelMealRule` — accepted meal slot on travel day → clear action
- Proper subscription cleanup in `watchConflicts` (prevents Drift timer leaks)
- `conflictFeedProvider` Riverpod provider

### 6. Recipe & Ingredient data layer (`lib/features/meals/`)
- `RecipeRepository` + `IngredientRepository` with Drift-backed CRUD
- `RecipeEditScreen` — full ingredient editor (add/remove/save)
- `RecipesScreen` — list of recipes with FAB

### 7. MealSuggester (`lib/features/meals/meal_suggester.dart`)
- Pure class, injectable `Random` for determinism in tests
- Hard constraints: travel day → empty; gym day → high-protein only
- Preference constraints: work lunch → quick, reza-day → reza-friendly
- History exclusion: no repeat within 3 days
- Post-gym shake slot auto-injected

### 8. Weekly meal grid + Sunday flow (`lib/features/meals/meals_screen.dart`)
- `MealsScreen` — week navigator + scrollable 7×4 slot grid
- Per-cell eat / skip / clear actions
- "Suggest week" — runs `MealSuggester` and upserts slots as `suggested`
- "Accept & shop" — accepts week then generates shopping collection and navigates to it

### 9. Shopping list generation (`lib/features/meals/shopping_generator.dart`)
- `ShoppingGenerator.generateForWeek` — aggregates accepted/eaten slots
- Unit-aware amount summing (same ingredient + unit → merged)
- Idempotent: returns existing collection id if already generated for that week

### Router & navigation
- `app_router.dart` — all 9 Agent 5 routes wired: `/trips`, `/trips/:id`, `/reminders`, `/partner`, `/meals`, `/recipes`, `/recipe/new`, `/recipe/:id`
- `MoreScreen` — Travel Planner, Reminders, Partner Schedule entries
- `TrackScreen` — Meals entry added
- `TodayScreen` — `_ConflictFeed` live widget + `_TodayMeals` section

### Tests
- `test/core/conflicts/conflict_engine_test.dart` — all 3 rules + actions (✅ pass)
- `test/features/meals/meal_suggester_test.dart` — 12 constraint/edge-case tests (✅ pass)
- `test/features/meals/shopping_generator_test.dart` — 7 aggregation tests (✅ pass)
- `test/features/reminders/reminder_repository_test.dart` — 6 isActiveOn + 7 CRUD tests (✅ pass after notification channel mock)

---

## Remaining / Known Issues

### 1. `nav_shell_test.dart` — "No exceptions across all 5 tabs" (timer pending)
**Root cause:** Drift's `StreamQueryStore.markAsClosed` creates a `Future.delayed(Duration.zero)` fake timer when a stream subscription is cancelled during `ProviderScope` disposal. This timer fires AFTER the test framework checks `!timersPending`.

This was a **pre-existing issue** (present before Agent 5's changes — confirmed in the first test run where "No exceptions" was already failing). Agent 5's addition of `_ConflictFeed` to TodayScreen adds one more Drift stream subscription, making the timer count slightly higher, but the failure mode was already present.

**Proper fix** (not yet applied — needs platform-level change):  
Extend `appDatabaseProvider` with `ref.onDispose(() => db.close())`, or call `tester.pump(Duration.zero)` at the end of the test body to drain Drift's deferred-close timers before the framework checks.

### 2. `gym_widget_test.dart` — 2 failures (timer pending)  
Pre-existing. Same Drift timer issue, introduced by Agent 4's `GymScreen` stream subscriptions. Not in Agent 5's scope.

### 3. `finance/widget_test.dart` — 1 timeout  
Pre-existing. `TransactionTile` test streams never settle. Not in Agent 5's scope.

### 4. Conventional commits not yet made  
The 9 per-step commits listed in the spec have not been created:
```
feat(trips): trip lifecycle with auto day-tags
feat(trips): planner screens
feat(reminders): windowed reminders
feat(partner): partner overlay
feat(conflicts): rule engine v1
feat(meals): recipe data layer
feat(meals): weekly suggestions
feat(meals): week grid and Sunday flow
feat(meals): shopping list generation
```
All work is in a single bulk commit instead.

### 5. `flutter analyze` — not verified green after final edits  
Run `flutter analyze` to confirm zero issues before merge.
