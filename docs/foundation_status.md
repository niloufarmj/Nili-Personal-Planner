# Foundation Layer — Status

**Branch:** `main` (all commits from `feat/foundation` merged inline)
**Agent:** Agent 1 of 5
**Last updated:** 2026-06-11

---

## Completed Steps

### Step 1 — Project structure & lint rules
- `pubspec.yaml` with all dependencies (drift, riverpod, go_router, table_calendar, rrule, flutter_local_notifications, archive, share_plus, file_picker, image_picker, flutter_image_compress, intl, shared_preferences, uuid, collection, path, path_provider, timezone)
- `analysis_options.yaml` with strict-casts, strict-raw-types, prefer_single_quotes, avoid_print, prefer_const_constructors, require_trailing_commas

### Step 2 — Full drift schema (28 tables across 9 domains)
Files: `lib/core/db/tables/`

| Domain | Tables |
|--------|--------|
| Core / Day | `Tags`, `DayTags`, `Events`, `Trips`, `Reminders` |
| Lists | `Collections`, `Items`, `Subtasks` |
| Finance | `Transactions`, `RecurringTransactions`, `Debts` |
| Meals | `Ingredients`, `Recipes`, `RecipeIngredients`, `MealSlots` |
| Fitness | `WorkoutPlans`, `GymSessions`, `Measurements`, `FitnessGoals`, `Habits`, `HabitLogs` |
| Wellbeing | `WellbeingActions`, `WellbeingLogs` |
| Work | `WorkContexts`, `TimeEntries` |
| Social | `SocialAccounts`, `SocialLogs` |
| Settings | `AppSettings` |

Type converters: `StringListConverter` (List\<String\>↔TEXT), `JsonMapConverter` (Map\<String,dynamic\>↔TEXT).
Database class: `lib/core/db/database.dart` with `appDatabaseProvider`.

### Step 3 — Design system
- `lib/core/design/app_colors.dart` — location overlays (linz=#F5C518, salzburg=#7C5CBF, travel=#3EBF6F), priority colours, category palette, `forTagName()`, `forPriority()`
- `lib/core/design/app_theme.dart` — Material 3, light + dark, seeded from salzburg purple
- Shared widgets: `AppCard`, `StatusChip`, `PriorityBadge`, `EmptyState`, `SectionHeader`, `ConfirmDialog`
- Barrel export: `lib/core/design/design.dart`

### Step 4 — Navigation shell (5-tab go_router)
- `lib/core/router/routes.dart` — route constants + path builders
- `lib/core/router/app_router.dart` — `StatefulShellRoute.indexedStack`, `agentRoutes []` extension point for agents 2–5
- `lib/core/router/shell_scaffold.dart` — `BottomNavigationBar` wired to `shell.goBranch()`
- Tabs: Today `/`, Calendar `/calendar`, Lists `/lists`, Track `/track`, More `/more`

### Step 5 — Tags & DayTags
- `lib/core/db/repositories/day_repository.dart` — `seedDefaultTagsIfNeeded()` (6 defaults: linz, salzburg, travel, gym, work, reza-day), `watchTagsForRange()`, `setTag()`, `removeTag()`, `setTagByNameForRange()`
- `lib/features/more/tag_manager_screen.dart` — create/edit tags via bottom sheet
- `lib/features/calendar/day_tag_picker.dart` — `FilterChip` per tag

### Step 6 — Events with RRULE expansion
- `lib/core/db/repositories/event_repository.dart` — CRUD + `expandOccurrences(start, end)` with O(window) rrule iteration
- `lib/features/calendar/event_edit_sheet.dart` — date/time picker, category/owner chips, weekly repeat toggle with optional end date
- RRULE format: `RRULE:FREQ=WEEKLY;BYDAY=MO;UNTIL=20251231T000000Z`

### Step 7 — Calendar aggregator
- `lib/core/calendar/calendar_day_data.dart` — `CalendarDayData` model (overlayColor, activityIcons, eventOccurrences, tripBars, mealDots, gymSession, dueDots, activeReminders, partnerTags, partnerEvents) + `CalendarFilter` with `copyWith()`
- `lib/core/calendar/calendar_aggregator.dart` — `CalendarAggregator.getDataForRange()` merging all sources in parallel. Overlay precedence: travel > linz/salzburg. Provider: `calendarAggregatorProvider`

### Step 8 — Calendar UI + day detail
- `lib/features/calendar/calendar_screen.dart` — `TableCalendar` month view with custom day cells (overlay tint, dot row), filter chip bar persisted in `SharedPreferences` via `_calendarFilterProvider` (bitmask)
- `lib/features/calendar/day_detail_screen.dart` — `DayTagPicker` + events list with edit actions + placeholder sections (meals/gym/due items) + add-event FAB

### Step 9 — Today screen
- `lib/features/today/today_screen.dart` — day overview strip (gym/meals/travel/due chips), today's events with category icons, `ConflictFeed` placeholder, habits placeholder
- Quick-add FAB: Event (opens `EventEditSheet`), Expense/Task/Trip/Note (guarded with "coming soon" snackbar)
- Tag sheet accessible from AppBar action

### Step 10 — Shared services
- `lib/core/services/notification_service.dart` — `scheduleAt()`, `scheduleDailyBatch()`, `cancel()`, `cancelAll()`, Android 13+ permission request, timezone-aware (`timezone` package)
- `lib/core/services/image_service.dart` — `pick()` (gallery/camera), compress+save via `flutter_image_compress`, `delete()`, `listAll()`, `saveBytes()` for restore
- `lib/core/services/backup_service.dart` — `exportAndShare()` / `exportToFile()` (zip: planner.db + images/ + manifest.json), `importFromPicker()` / `restoreFromPath()`, `shouldNudge()` (30-day reminder), `lastBackupTime()`

### Step 11 — Contracts doc
- `docs/contracts.md` covering: directory ownership rules, DB access pattern, design system, navigation/routes, `CalendarAggregator` integration contract, `DayRepository` API, `NotificationService` / `ImageService` / `BackupService` APIs, `ConflictFeed` interface, per-agent notification ID namespaces, and the feature checklist for agents 2–5.

Also fixed: `BackupService` was referencing `planner.db` but the Drift database file is `app.db` — corrected in all four places in `backup_service.dart`.

---

## Test Coverage

| File | Tests |
|------|-------|
| `test/core/db/database_test.dart` | 21 |
| `test/core/design/design_system_test.dart` | 32 |
| `test/features/nav_shell_test.dart` | 7 |
| `test/core/db/day_repository_test.dart` | 9 |
| `test/core/db/event_repository_test.dart` | 7 |
| `test/core/calendar/calendar_aggregator_test.dart` | 13 |
| **Total** | **89** |

`flutter analyze` — **0 issues** on all commits.

---

## Key Architecture Notes for Agents 2–5

- **DB access:** always go through a `*Repository` class, never query `AppDatabase` directly from a feature screen.
- **Riverpod:** use `ref.watch(appDatabaseProvider)` inside providers; override `appDatabaseProvider` in `main.dart` with the real DB instance.
- **New routes:** add `GoRoute(...)` entries to the `agentRoutes` list in `lib/core/router/app_router.dart`.
- **New tab content:** replace the stub `EmptyState` in `lists_screen.dart` / `track_screen.dart` / `more_screen.dart` — do not touch `shell_scaffold.dart`.
- **Notifications:** call `NotificationService().init()` once (idempotent) before scheduling.
- **Images:** use `ImageService.pick()` → store the returned path in the relevant DB column.
- **Backup:** `BackupService` reads the DB file directly by path — no drift teardown needed.
