# Shared API Contracts — Agents 2–5

This document is the authoritative reference for every boundary that crosses feature areas.
Read it before writing a single line in `lib/features/<your-feature>/`.

---

## 1. Directory Rule

Each agent owns exactly one directory:

| Agent | Directory |
|-------|-----------|
| 1 (Foundation) | `lib/core/` |
| 2 (Lists & Finance) | `lib/features/lists/`, `lib/features/finance/` |
| 3 (Fitness & Meals) | `lib/features/fitness/`, `lib/features/meals/` |
| 4 (Work & Social) | `lib/features/work/`, `lib/features/social/` |
| 5 (Wellbeing & Conflicts) | `lib/features/wellbeing/`, `lib/features/conflicts/` |

**Never** write to another agent's directory.
**Extension points** that require touching shared files are described in the sections below —
those are the only exceptions, and the files explicitly say so with a comment.

---

## 2. Database Access Pattern

### Getting the DB instance

```dart
// Inside a Riverpod provider:
final myRepoProvider = Provider<MyRepository>(
  (ref) => MyRepository(ref.watch(appDatabaseProvider)),
);
```

`appDatabaseProvider` throws if not overridden — it is wired in `main.dart` with the real
`AppDatabase` instance. Never construct `AppDatabase()` yourself inside a feature.

### Repository rules

- Create a `*Repository` class that takes `AppDatabase` as a constructor parameter.
- Never query `AppDatabase` directly from a screen or widget.
- Use Drift's generated table accessors (`_db.myTable`) and typed companions.
- Date columns are stored as `TEXT` in `YYYY-MM-DD` format (ISO 8601, no time component).
- DateTime columns with time are stored as `TEXT` in full ISO 8601 (`toIso8601String()`).
- `StringListConverter` — serialize `List<String>` to/from a JSON array TEXT column.
- `JsonMapConverter` — serialize `Map<String, dynamic>` to/from a TEXT column.

### Schema version

Current `schemaVersion = 1`. Add migrations in `AppDatabase.migration.onUpgrade` only;
never change `onCreate`.

---

## 3. Design System

Import everything from the barrel:

```dart
import 'package:nili_personal_planner/core/design/design.dart';
```

### Colours

```dart
AppColors.linz         // #F5C518 — location overlay
AppColors.salzburg     // #7C5CBF — location overlay
AppColors.travel       // #3EBF6F — location overlay
AppColors.forTagName(String name) // → Color? (null if unrecognised)
AppColors.forPriority(String p)   // 'high'|'medium'|'low' → Color
```

Full category palette is in `AppColors.categoryPalette` (Map<String, Color>).

### Shared widgets

| Widget | Purpose |
|--------|---------|
| `AppCard` | Standard elevated card; use instead of raw `Card` |
| `StatusChip` | Coloured chip for status strings (e.g. `'open'`, `'done'`) |
| `PriorityBadge` | Coloured dot + label for priority |
| `EmptyState` | Centered icon + message + hint for empty lists |
| `SectionHeader` | Bold section title with optional trailing action |
| `ConfirmDialog` | Standard "are you sure?" dialog — use before destructive actions |

### Theme

The app uses Material 3 seeded from salzburg purple. Always use
`Theme.of(context).colorScheme.*` and `Theme.of(context).textTheme.*` — no hardcoded colours.

---

## 4. Navigation

### Route constants

All route paths live in `lib/core/router/routes.dart`:

```dart
Routes.today        // '/'
Routes.calendar     // '/calendar'
Routes.lists        // '/lists'
Routes.track        // '/track'
Routes.more         // '/more'
Routes.dayDetail    // '/day/:date'  — date = YYYY-MM-DD
Routes.collection   // '/collection/:id'
Routes.trip         // '/trip/:id'

// Path builders:
Routes.dayDetailPath(String date)   // '/day/2026-06-11'
Routes.collectionPath(int id)       // '/collection/42'
Routes.tripPath(int id)             // '/trip/7'
```

### Adding routes (extension point)

Append your `GoRoute` entries to the `agentRoutes` list in
`lib/core/router/app_router.dart`:

```dart
// lib/core/router/app_router.dart — extension point
final List<RouteBase> agentRoutes = [
  GoRoute(
    path: '/expense/new',
    builder: (context, state) => const ExpenseEditSheet(),
  ),
  // …
];
```

Shell-tab content (Lists, Track, More) is replaced by editing the stub screen inside
the corresponding `*_screen.dart` file — do **not** touch `shell_scaffold.dart`.

### Navigation from a widget

```dart
context.go(Routes.dayDetailPath('2026-06-11'));
context.push('/expense/new');
```

### "Coming soon" guard (Today quick-add)

Routes that exist but whose screen is not yet built should navigate to the named route and
let `app_router.dart`'s `_stubScreen` render the placeholder automatically.
Do not show a SnackBar instead — proper routing is required.

---

## 5. CalendarAggregator Contract

### Purpose

`CalendarAggregator` is the single source of truth for what the calendar cell shows.
Agents contribute data by writing to their DB tables — the aggregator reads those tables
and merges them into `CalendarDayData`.

### Provider

```dart
final calendarAggregatorProvider = Provider<CalendarAggregator>(...);
// ref.watch(calendarAggregatorProvider)
```

### Primary API

```dart
Future<Map<String, CalendarDayData>> getDataForRange(
  DateTime start,
  DateTime end, {
  CalendarFilter filter = CalendarFilter.all,
})
```

Returns a map keyed by `'YYYY-MM-DD'` for every day in the range.

### CalendarDayData fields

| Field | Type | Populated by |
|-------|------|--------------|
| `overlayColor` | `Color?` | location tags (linz/salzburg/travel) |
| `activityIcons` | `List<IconData>` | activity tags (gym, work) |
| `eventOccurrences` | `List<EventOccurrence>` | Events table |
| `tripBars` | `List<Trip>` | Trips table (`status='final'`) |
| `mealDots` | `int` | MealSlots table |
| `gymSession` | `GymSession?` | GymSessions table |
| `dueDots` | `int` | Items table (`due_date`) |
| `activeReminders` | `List<Reminder>` | Reminders table |
| `partnerTags` | `List<Tag>` | Tags with `owner='partner'` |
| `partnerEvents` | `List<EventOccurrence>` | Events with `owner='partner'` |

### How to surface your module's data on the calendar

1. Write your data to the appropriate existing table (e.g. `MealSlots`, `GymSessions`,
   `Items.dueDate`, `Trips`).
2. The aggregator already reads those tables — no code change needed.
3. If you need a new data type on the cell, add a field to `CalendarDayData` and a
   corresponding `_apply*` method in `CalendarAggregator`, plus a flag in `CalendarFilter`.
   Coordinate with Agent 1 before changing these files.

### CalendarFilter

```dart
CalendarFilter(
  showLocation: true,   // location overlays
  showGym: true,        // gym session icon + gymSession field
  showMeals: true,      // mealDots
  showWork: true,       // work events
  showUni: true,        // uni events
  showTravel: true,     // tripBars
  showSocial: true,     // social events
  showTasks: true,      // dueDots
  showPartner: true,    // partner strip
  showReminders: true,  // reminder banners
)
CalendarFilter.all       // all true (default)
filter.copyWith(showGym: false)
```

---

## 6. Day-Tag Repository API

Provider: `dayRepositoryProvider`

```dart
// Seeding (called once on startup in main.dart)
await repo.seedDefaultTagsIfNeeded();

// Tags catalogue
Stream<List<Tag>> watchAllTags()
Future<List<Tag>> getAllTags()
Future<Tag>       getTag(int id)
Future<int>       createTag({required String name, required String color,
                              required String kind, String owner = 'me'})
Future<void>      updateTag(Tag tag)

// Day assignments
Stream<Map<String, List<Tag>>> watchTagsForRange(DateTime start, DateTime end)
Future<List<Tag>>               getTagsForDate(String date)   // date = 'YYYY-MM-DD'
Future<void>  setTag(String date, int tagId, {String source = 'manual'})
Future<int>   removeTag(String date, int tagId)
Future<void>  setTagByNameForRange(String tagName, DateTime start, DateTime end,
                                    {String source = 'trip'})
```

### Tag `kind` values

| kind | Meaning |
|------|---------|
| `'location'` | Full-cell overlay (linz / salzburg / travel) |
| `'activity'` | Activity icon in cell (gym, work) |
| `'special'` | Special marker (reza-day → heart icon) |
| `'partner'` | Partner-strip tag |

---

## 7. NotificationService API

Singleton — access via `NotificationService()` or `ref.watch(notificationServiceProvider)`.

```dart
// Init (idempotent — safe to call multiple times)
await NotificationService().init();

// Android 13+ permission request (call once after first launch)
final granted = await NotificationService().requestPermission();

// One-off notification
await service.scheduleAt(
  id: 42,            // unique int — you own your ID namespace
  title: 'Title',
  body: 'Body',
  when: DateTime.now().add(const Duration(hours: 1)),
  payload: '/expense/42',  // optional deep-link path
);

// Daily repeating notification
await service.scheduleDailyBatch(
  id: 100,
  title: 'Daily summary',
  body: 'Check your plan',
  hour: 8,
  minute: 0,
);

// Cancel
await service.cancel(id);
await service.cancelAll();
```

### Notification ID namespaces (reserve ranges per agent)

| Agent | Range |
|-------|-------|
| 1 (Foundation) | 1–99 |
| 2 (Lists & Finance) | 100–199 |
| 3 (Fitness & Meals) | 200–299 |
| 4 (Work & Social) | 300–399 |
| 5 (Wellbeing & Conflicts) | 400–499 |

---

## 8. ImageService API

Provider: `imageServiceProvider`

```dart
// Pick from gallery or camera; returns absolute local path or null if cancelled
final path = await imageService.pick(source: ImageSource.gallery);
final path = await imageService.pick(source: ImageSource.camera);

// Save raw bytes (e.g. from backup restore)
final path = await imageService.saveBytes(bytes, name: 'optional_name.jpg');

// Delete
await imageService.delete(localPath);

// List all stored images
final paths = await imageService.listAll();
```

Images are stored under `<appDocuments>/images/` as UUID-named JPEGs, compressed to
≤80% quality at max 1024 px on the short side. Store only the **absolute path** in DB
columns — do not store relative paths.

---

## 9. BackupService API

Provider: `backupServiceProvider`

```dart
// Export & share via OS share sheet; returns zip path
final zipPath = await backup.exportAndShare();

// Export to file without sharing
final zipPath = await backup.exportToFile();

// Import: opens file picker → restores DB + images; returns true on success
final ok = await backup.importFromPicker();

// Restore from known path (e.g. after automated test)
final ok = await backup.restoreFromPath('/path/to/file.zip');

// 30-day nudge
final needsNudge = await backup.shouldNudge();
final lastTime   = await backup.lastBackupTime(); // DateTime? (null = never)
```

### Zip layout

```
manifest.json     — { "version": 1, "exported_at": "<iso8601>", "db": "app.db" }
app.db            — copy of the SQLite database
images/           — all images from <appDocuments>/images/
```

The restore replaces `app.db` in place. The app must be restarted (or the Drift connection
re-opened) for changes to take effect — `ConfirmDialog` should warn the user.

---

## 10. ConflictFeed Interface

The `TodayScreen` reads conflicts from a `ConflictFeed` interface defined in
`lib/features/today/today_screen.dart`. Agent 5 implements the live engine.
Until then the feed returns an empty list.

```dart
abstract interface class ConflictFeed {
  Stream<List<ConflictItem>> watchConflicts(DateTime date);
}

class ConflictItem {
  final String message;
  final ConflictSeverity severity; // info | warning | error
}
```

To wire up the real engine: implement `ConflictFeed` in
`lib/features/conflicts/conflict_engine.dart` and provide it via Riverpod,
overriding `conflictFeedProvider` in your feature bootstrap.

---

## 11. Checklist for Adding a Feature

1. All Dart files in `lib/features/<your-feature>/`.
2. Repository class wrapping `AppDatabase` — no direct table queries in widgets.
3. Routes added to `agentRoutes` in `lib/core/router/app_router.dart`.
4. Tab content (if any) replacing `EmptyState` in the existing `*_screen.dart` stub.
5. Notification IDs from your allocated range.
6. Image paths stored as absolute strings in DB columns.
7. `flutter analyze` — zero issues before committing.
8. `flutter test` — all existing tests green; new tests for your code.
