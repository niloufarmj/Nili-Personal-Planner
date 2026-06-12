# Personal Planner — Multi-Agent Build Plan

5 agent prompts + initial setup. **Agent 1 must finish before Agents 2–5 start** (they depend on the database, design system, and shared services Agent 1 creates). Agents 2–5 can then run in parallel on separate branches.

---

## Part A — Your one-time setup (before any agent runs)

### 1. Install the toolchain

```bash
# 1. Install Flutter SDK (stable channel) — https://docs.flutter.dev/get-started/install
#    On Windows: download the zip, extract to C:\dev\flutter, add C:\dev\flutter\bin to PATH

# 2. Verify
flutter doctor
# Fix anything red. You need at minimum: Flutter, Android toolchain, VS Code.

# 3. Android emulator: install Android Studio (just for SDK + emulator),
#    then create a device via Device Manager (e.g. Pixel 8, API 35).
#    NOTE: iOS builds require a Mac — develop/test on Android first; the code stays cross-platform.
```

### 2. VS Code extensions
Install: **Flutter** (includes Dart), **GitLens** (optional), **Error Lens** (optional).

### 3. Create the project

```bash
flutter create personal_planner --org com.nili --platforms android,ios
cd personal_planner

git init
git add -A
git commit -m "chore: flutter project scaffold"
```

### 4. Add dependencies

```bash
flutter pub add drift drift_flutter sqlite3_flutter_libs path_provider path \
  flutter_local_notifications table_calendar fl_chart intl rrule \
  image_picker flutter_image_compress share_plus file_picker archive \
  flutter_riverpod go_router

flutter pub add dev:drift_dev dev:build_runner dev:flutter_lints

git add -A && git commit -m "chore: add core dependencies"
```

### 5. Put the design doc in the repo

```bash
mkdir docs
# copy personal-planner-design-doc.md into docs/design.md
git add docs && git commit -m "docs: add design documentation v1.0"
```

### 6. Branch model
- `main` — only merged, tested work
- Agent 1 works on `feat/foundation`, merges to `main` when done
- Agents 2–5 branch off `main` after that: `feat/list-engine`, `feat/finance-work`, `feat/health`, `feat/planning-meals`
- Merge order back to main: 2 → 3 → 4 → 5 (resolve conflicts at each merge; they should be minimal since each agent owns its own `lib/features/<name>/` directory)

### 7. Rules every agent follows (included in each prompt)
- Conventional commits (`feat:`, `fix:`, `test:`, `chore:`)
- Before **every** commit: `dart format .` → `flutter analyze` (zero issues) → `flutter test` (all green)
- Never edit another agent's feature directory; shared code changes go through `lib/core/` only if your prompt explicitly allows it

---

## Part B — Agent prompts

---

### AGENT 1 — Foundation & Core Hub

```
You are Agent 1 of 5 building "Personal Planner", a fully local Flutter app (no server, no accounts). Read docs/design.md completely before writing any code — it contains the full schema, architecture, and UX spec. You own the foundation that all other agents depend on, so API stability and test coverage matter more than speed.

WORK ON BRANCH: feat/foundation

YOUR SCOPE (and nothing else):
1. Project structure & conventions
2. Complete drift database (ALL tables from docs/design.md section 4, even ones used by other agents)
3. Design system & theming
4. Navigation shell (5 tabs)
5. Core day layer: tags, day_tags, events (with RRULE expansion)
6. Main calendar with overlays and filters + day detail sheet
7. Today screen
8. Shared services: notifications, image storage, backup/export
9. Documentation of all shared APIs in docs/contracts.md

PROCESS RULES:
- Work in the step order below. After EACH step: run `dart format .`, `flutter analyze` (must be zero issues), `flutter test` (must be all green), then commit with a conventional commit message. One commit per step minimum.
- Every step includes its tests — a step is not done until its tests pass.
- State management: Riverpod. Routing: go_router. Database: drift with reactive (watch) queries so UI auto-updates.

STEPS:

Step 1 — Structure & lint (commit: "chore: project structure and lint rules")
Create directory layout:
  lib/core/db/          (drift database)
  lib/core/design/      (theme, colors, typography, shared widgets)
  lib/core/services/    (notifications, images, backup)
  lib/core/calendar/    (shared calendar widget + aggregator)
  lib/features/today/
  lib/features/calendar/
  lib/features/settings/
Configure analysis_options.yaml with flutter_lints, strict-casts and strict-raw-types enabled.

Step 2 — Full drift schema (commit: "feat(db): complete drift schema v1")
Implement EVERY table from docs/design.md section 4 exactly: tags, day_tags, events, trips, reminders, collections, items, subtasks, transactions, recurring_transactions, debts, ingredients, recipes, recipe_ingredients, meal_slots, workout_plans, gym_sessions, measurements, fitness_goals, habits, habit_logs, wellbeing_actions, wellbeing_logs, work_contexts, time_entries, social_accounts, social_logs. Money is integer cents. Dates are ISO-8601 TEXT. JSON columns are TEXT with typed converters (write the converters). Set schemaVersion = 1 and wire MigrationStrategy for future versions. Run build_runner. 
TESTS: in-memory database test that opens the DB, inserts and reads one row per table, verifies type converters round-trip JSON correctly.

Step 3 — Design system (commit: "feat(design): theme, palette, shared components")
Light + dark themes. Color constants including: linz #F5C518, salzburg #7C5CBF, travel #3EBF6F, plus priority colors (high/normal/low) and a category palette. Typography scale. Shared widgets: AppCard, StatusChip, PriorityBadge, EmptyState (icon + one-line explainer + sample hint), SectionHeader, ConfirmDialog. 
TESTS: widget tests rendering each shared widget in light and dark mode without exceptions.

Step 4 — Navigation shell (commit: "feat(nav): 5-tab shell with go_router")
Bottom navigation: Today, Calendar, Lists, Track, More. Lists/Track/More show placeholder screens with EmptyState (other agents fill them). Deep-linkable routes for: /day/:date, /collection/:id, /trip/:id (stub targets are fine).
TESTS: widget test that all 5 tabs render and switch without exceptions.

Step 5 — Tags & day_tags (commit: "feat(core): day tags with repository and editor")
DayRepository with watchTagsForRange(start, end), setTag/removeTag(date, tagId, source). Seed default tags on first launch: linz, salzburg, travel (location); gym, work (activity); reza-day (special). Tag editor UI: tag manager in More tab (create/edit/archive tags, pick color and kind) and a per-day tag picker (used by day detail sheet).
TESTS: repository unit tests (set, remove, watch emits updates, duplicate tag on same day is idempotent, source field respected).

Step 6 — Events with recurrence (commit: "feat(core): events with RRULE expansion")
EventRepository: CRUD + expandOccurrences(start, end) that expands rrule strings (use the rrule package) into concrete dates within a window. Event create/edit sheet: title, date, optional time range, location, category, weekly repeat shortcut (writes RRULE), owner (me/partner).
TESTS: unit tests for expansion — one-off event, weekly repeat over 6 weeks, repeat with end date, event with no rrule.

Step 7 — Calendar aggregator (commit: "feat(calendar): aggregation layer")
CalendarAggregator service: given a date range and a set of enabled source filters, returns per-day render data by merging: day_tags (location → overlay color, activity → icons), events (dots + agenda), trips with status final (range bars), items.due_date (dots), reminders (active window banners), gym_sessions, meal_slots, partner-owned rows (separate strip channel). Define a CalendarDayData model. Sources that have no data yet (other agents' modules) must work and simply return empty — the aggregator queries the tables directly, which already exist from Step 2.
TESTS: unit tests — overlay precedence (travel wins over linz/salzburg), multi-tag day, filter toggles exclude sources, empty DB returns clean empty days.

Step 8 — Main calendar UI + day detail sheet (commit: "feat(calendar): main calendar with filters and day sheet")
Month view (table_calendar) rendering CalendarDayData: full-cell color overlays, icons, dots, trip bars, partner strip at top of cell. Filter chip bar (multi-select, persisted in a simple key-value settings table or shared_preferences). Tap a day → day detail sheet: date + tags editor, agenda of events, placeholders sections for meals/gym/due items (other agents replace placeholders with real content via the aggregator — design the sheet to render whatever sections CalendarDayData contains).
TESTS: widget test — calendar renders a seeded month, tapping a day opens the sheet, toggling a filter hides its dots.

Step 9 — Today screen (commit: "feat(today): today screen with quick-add")
Today = the day detail content for today + quick-add FAB (Expense/Event/Task/Trip/Note — route to creation sheets; stub the ones owned by other agents behind a "coming soon" guard that routes correctly once they exist, i.e., navigate to named routes), + a notifications/conflicts card area (empty list for now, reads from a ConflictFeed interface you define — Agent 5 implements the engine).
TESTS: widget test that Today renders for an empty DB and for a seeded day.

Step 10 — Shared services (commit: "feat(services): notifications, images, backup")
NotificationService: initialize plugin, scheduleAt(id, dateTime, title, body), scheduleDailyBatch(id, timeOfDay, ...), cancel(id). Request permissions properly on Android 13+.
ImageService: pick from gallery/camera, compress (max 1600px, ~80 quality), save to app documents /images, return relative path; delete.
BackupService: export = zip app.db + /images with manifest.json (schema version, date), share via share_plus; import = pick file, validate manifest, replace DB and images after a ConfirmDialog, restart-safe. Add "last backup" timestamp surfaced in More with a 30-day nudge.
TESTS: unit tests for backup manifest validation and zip round-trip using temp dirs; notification service tested behind an interface with a fake.

Step 11 — Contracts doc (commit: "docs: shared API contracts for agents 2-5")
Write docs/contracts.md documenting: DB access pattern, design-system components, CalendarAggregator and how a module's data appears on the calendar, day-tag repository, NotificationService/ImageService APIs, navigation route names, and the rule that each agent only writes inside lib/features/<own-feature>/ plus registering routes/tabs in clearly marked extension points you create (e.g., a registry file per tab).

DEFINITION OF DONE: all steps committed, `flutter analyze` zero issues, `flutter test` green, app runs on an Android emulator showing working calendar with tags/events and a Today screen. Merge feat/foundation → main.
```

---

### AGENT 2 — Generic List Engine

```
You are Agent 2 of 5 building "Personal Planner" (local-only Flutter app). Read docs/design.md (especially sections 4.2 and 6) and docs/contracts.md before coding. Agent 1's foundation is on main: full DB schema, design system, navigation shell, calendar aggregator, services. You build the generic list engine that powers 12 pages.

WORK ON BRANCH: feat/list-engine (branched from main after Agent 1 merged)
YOU OWN: lib/features/lists/ only, plus the Lists-tab registry extension point.

PROCESS RULES: after each step run `dart format .`, `flutter analyze` (zero issues), `flutter test` (green), then commit (conventional commits). Use Riverpod + drift watch queries. Use only design-system components from lib/core/design.

STEPS:

Step 1 — Repositories (commit: "feat(lists): collection and item repositories")
CollectionRepository and ItemRepository over the existing tables: CRUD, watchCollections(parentId?), watchItems(collectionId, {filters, sort}), toggleItemStatus (sets/clears done_date), subtask CRUD, archive collection. Sorting: priority then due_date then manual sort_order.
TESTS: unit tests for CRUD, watch emission on change, done_date set on tick and cleared on untick, archived collections excluded by default.

Step 2 — Template registry (commit: "feat(lists): template system")
Implement the 9 templates from design.md 4.2 as a TemplateRegistry: template id → status vocabulary (+ colors), visible fields, meta-field definitions (typed: text/url/number/select), default sort, icon. Templates: simple, chore, shopping, upgrade, task, job, growth, media, probable. Item create/edit forms must be generated from the template definition — no per-template form code.
TESTS: unit tests that every template produces a valid form model; status transitions respect each template's vocabulary.

Step 3 — Lists tab (commit: "feat(lists): lists home grid")
Replace the Lists tab placeholder: grid of non-archived collections (icon, name, open/done counts), grouped by template kind, "+ New list" flow (name → template picker → optional parent). Long-press: rename/archive.
TESTS: widget test — empty state renders, creating a collection shows it in the grid.

Step 4 — Collection screen (commit: "feat(lists): collection detail with items")
Item list with template-driven rendering: StatusChip, PriorityBadge, due date, planned cost where the template defines it. Add/edit item sheet generated from template fields. Subtasks expandable inline with their own checkboxes; parent shows x/y progress. Image attach (upgrade template: before & after slots) via ImageService. Swipe to complete/delete with undo snackbar.
TESTS: widget tests per representative template (simple, task with subtasks, shopping with cost, upgrade with images-stubbed).

Step 5 — Recurring chores (commit: "feat(lists): chore recurrence")
Items with a recurrence RRULE (chore template): on completion, done_date is logged to a completion history (add a small chore_completions table via a schema migration v2 — coordinate by bumping drift schemaVersion and writing the migration) and the item resets to open with due_date advanced to the next occurrence. Overdue chores get a visual overdue state, never auto-delete.
TESTS: unit tests — daily/weekly/monthly advance correctly, completion history recorded, overdue detection.

Step 6 — Calendar integration (commit: "feat(lists): due dates on calendar")
Verify items.due_date dots appear on the main calendar via the aggregator (they should already — the aggregator reads the items table). Add the day detail sheet section for due items (tap-through to the item). Register a "Tasks" filter chip if not present.
TESTS: aggregator test seeded with due items across templates; widget test that day sheet lists them.

Step 7 — Seed collections (commit: "feat(lists): default collections, empty placeholders")
On first launch create empty default collections matching design.md: Chores (chore), Shopping (shopping), Tech Wishlist (shopping), Life Upgrades (upgrade), University (task), Personal Projects (task), Personal Growth (growth), Hobbies (media), Probable Plans (probable), Job Hunt parent with Germany/Netherlands/Spain/Australia children (job). NO content items — placeholders stay empty per the owner's instruction; data comes later.
TESTS: first-launch seeding test (idempotent — running twice doesn't duplicate).

DEFINITION OF DONE: analyze + tests green, Lists tab fully functional on emulator with all templates, merge to main (you merge first of agents 2-5; resolve any trivial conflicts).
```

---

### AGENT 3 — Finance, Work Time & Social Tracker

```
You are Agent 3 of 5 building "Personal Planner" (local-only Flutter app). Read docs/design.md (sections 4.3, 4.7, 4.8, 6) and docs/contracts.md. Foundation (Agent 1) is on main. The list engine (Agent 2) may merge before or after you — your only coupling to it is the shopping-item → expense link, which goes behind an interface (see Step 5).

WORK ON BRANCH: feat/finance-work
YOU OWN: lib/features/finance/, lib/features/worktime/, lib/features/social/, plus Track-tab registry entries.

PROCESS RULES: after each step run `dart format .`, `flutter analyze` (zero), `flutter test` (green), commit (conventional). All money displayed from integer cents with a single shared formatter you add to lib/core/design (allowed: one new file there, document it in docs/contracts.md).

STEPS:

Step 1 — Finance repositories (commit: "feat(finance): repositories")
TransactionRepository (CRUD, watchByMonth, filters by category/direction/status), RecurringRepository (CRUD, expandForMonth(month) → projected transactions), DebtRepository (CRUD, settle). 
TESTS: recurring expansion across month boundaries, end_month respected, inactive excluded; settle flow.

Step 2 — Forecast engine (commit: "feat(finance): monthly forecast")
ForecastService: for a given month compute — actual in/out to date, projected recurring remainder, planned transactions in month, estimated end-of-month balance, and per-category breakdown. Pure function over repository data.
TESTS: golden-number unit tests covering mid-month, planned+actual mix, income vs expense, empty month.

Step 3 — Finance UI (commit: "feat(finance): tracker screens")
Track tab entry "Finance": month pager; forecast card (estimated end-of-month, planned vs actual); transaction list grouped by day with quick-add (amount, direction, category, note, optional planned status and future date); recurring manager screen (subscriptions/rent/salary CRUD with active toggle); debts screen; charts (fl_chart): category donut for the month + 6-month in/out bars. Planned transactions visually distinct (outlined) and one-tap convertible to actual.
TESTS: widget tests — quick-add creates a row, forecast card renders seeded data, planned→actual conversion.

Step 4 — Calendar integration (commit: "feat(finance): planned expenses on calendar")
Planned transactions with future dates appear as dots via the aggregator under a "Finance" filter chip; day sheet section lists that day's transactions.
TESTS: aggregator + day-sheet widget test.

Step 5 — Shopping link (commit: "feat(finance): expense link interface")
Define ExpenseLinkService in lib/core/services (documented in contracts): createFromItem(itemId, title, plannedCost) and markBought(itemId, actualCost) → writes a transaction with item_id set. If Agent 2's UI is present, wire their "mark bought" action via this service; if not yet merged, the service plus tests stand alone and Agent 2/5 consume it later.
TESTS: unit tests — planned transaction created from item, bought converts to actual, idempotency (no duplicate transaction per item).

Step 6 — Work time tracking (commit: "feat(worktime): contexts and time entries")
Track tab entry "Work Time": work contexts CRUD (FreshFX, Tutoring, Startup seeded empty-ready — create contexts but no entries); time entry quick-add (context, optional task item id, date, minutes, note) + a running timer (start/stop writes an entry); rollups screen — today / this week / per month per context, and the overtime counter: configurable baseline hours-per-week, surplus accumulates and displays as "saved days" (surplus ÷ 8h).
TESTS: rollup math unit tests (week boundaries, multiple contexts), overtime counter with configurable baseline, timer writes correct minutes (injectable clock).

Step 7 — Social media tracker (commit: "feat(social): accounts and logs")
Track tab entry "Social": accounts CRUD (platform, goal), daily log quick-add (minutes, activity type, note), per-account history list, weekly minutes bar chart, simple streak/“last posted X days ago” indicator per account computed from logs with activity=post/story.
TESTS: streak computation unit tests, log CRUD, chart data mapping.

DEFINITION OF DONE: analyze + tests green, Finance/Work Time/Social all functional from Track tab on emulator, merge to main after Agent 2.
```

---

### AGENT 4 — Health: Gym, Fitness, Habits, Wellbeing

```
You are Agent 4 of 5 building "Personal Planner" (local-only Flutter app). Read docs/design.md (sections 4.5, 4.6, 6, 7) and docs/contracts.md. Foundation is on main. You own everything health-related. Remember the product principle: one-tap logging — every recurring input must be ≤2 taps from the Today screen.

WORK ON BRANCH: feat/health
YOU OWN: lib/features/gym/, lib/features/fitness/, lib/features/habits/, lib/features/wellbeing/, plus Track-tab registry entries and Today-screen section extensions (use the extension points from contracts.md only).

PROCESS RULES: after each step run `dart format .`, `flutter analyze` (zero), `flutter test` (green), commit (conventional).

STEPS:

Step 1 — Gym plans & sessions (commit: "feat(gym): plans and session logging")
WorkoutPlanRepository (CRUD, markdown content rendered read-only nicely) — seed three EMPTY plans named A, B, C (content filled later by the owner). GymSessionRepository: plan sessions ahead (date + plan), log done (start time, duration, notes), watchUpcoming, watchHistory. Auto-missed rule: a daily maintenance task (run on app open) marks past 'planned' sessions as 'missed' — kept for stats, hidden from upcoming.
TESTS: auto-missed transitions (yesterday planned → missed; today planned → untouched), history ordering, plan CRUD.

Step 2 — Gym UI + calendar (commit: "feat(gym): screens and calendar dots")
Track entry "Gym": upcoming planned sessions, one-tap "Done today" (picks plan, default duration editable), plan viewer, weekly attendance stat (done/week vs target 3), monthly history. Calendar: outlined dot = planned, filled = done, via aggregator under "Gym" chip; day sheet gym section with quick actions. Planning UI must read day_tags and visually grey/warn on days tagged travel (read-only awareness here — the full conflict engine is Agent 5's; just don't block).
TESTS: widget tests for one-tap logging; aggregator test for planned/done dots; travel-day warning rendering.

Step 3 — Measurements & goals (commit: "feat(fitness): measurements, photos, charts, goals")
Track entry "Fitness": add measurement entry (date, weight, user-definable numeric fields stored in the JSON fields column — field definitions managed in a small settings UI), attach photos via ImageService (private to app storage); history list; weight + per-field line charts over time (fl_chart); goals CRUD (metric, target, deadline) with achieved detection when a new measurement crosses the target; weekly reminder (NotificationService, default Sunday 18:00, editable) and monthly photo+measurement reminder.
TESTS: goal-achievement detection (crossing up and down depending on direction), JSON field round-trip, chart series mapping, reminder scheduling via fake notification service.

Step 4 — Habits engine (commit: "feat(habits): counters and batched reminders")
HabitRepository over habits/habit_logs: increment/decrement count for today, watchToday, streaks. Seed default habits EMPTY-config-ready: Water (target 8), Skincare AM, Skincare PM, Teeth (target 2), Reading. Batched reminders: each habit's reminder_times JSON schedules daily notifications via NotificationService — defaults batched at 09:00/13:00/17:00/21:00, never hourly. Habit manager UI (edit targets, times, active).
TESTS: increment/decrement bounds (never negative), streak math across gaps, scheduling produces exactly the configured notifications (fake service).

Step 5 — Today integration (commit: "feat(habits): today tap counters")
Today screen habit row: one tap-counter chip per active habit (water shows 3/8 with a tap = +1, long-press = −1), gym quick "Done" if a session is planned today. This is the most-used UI in the app — make it satisfying (subtle animation, haptic).
TESTS: widget test — tap increments and persists, long-press decrements.

Step 6 — Feeling Better page (commit: "feat(wellbeing): actions and history")
Track entry "Feeling Better": today's action checklist from wellbeing_actions (seed: meditation, talk to a friend, listen to music — user can add/edit), tap to log/unlog for today; history view = month calendar heat dots (any action logged that day = dot, more actions = stronger dot) reusing the shared calendar widget filtered to wellbeing only.
TESTS: log/unlog idempotency, heat mapping by count, custom action CRUD.

DEFINITION OF DONE: analyze + tests green, all four areas functional on emulator, habit counters live on Today, merge to main after Agent 3.
```

---

### AGENT 5 — Planning Layer & Meals: Trips, Reminders, Partner, Conflict Engine, Meal Planner

```
You are Agent 5 of 5 building "Personal Planner" (local-only Flutter app). Read docs/design.md (sections 3, 4.1, 4.4, 5, 6) and docs/contracts.md. Foundation is on main; ideally merge after Agents 2–4 since you consume the list engine (packing lists, shopping generation) and provide the conflict engine that touches gym data. You own the connective tissue that makes this app different from Notion.

WORK ON BRANCH: feat/planning-meals
YOU OWN: lib/features/trips/, lib/features/reminders/, lib/features/partner/, lib/features/meals/, lib/core/conflicts/ (new, documented in contracts.md), plus More/Track registry entries.

PROCESS RULES: after each step run `dart format .`, `flutter analyze` (zero), `flutter test` (green), commit (conventional).

STEPS:

Step 1 — Trips (commit: "feat(trips): trip lifecycle with auto day-tags")
TripRepository: CRUD with status flow probable → final → done (or cancelled). On final: write 'travel' day_tags (source='trip') for the date range and create a packing-list collection (template simple) linked via packing_collection_id; on date/status change: reconcile tags (remove stale, add new — only touch source='trip' tags); on cancel: remove its tags, keep the trip row. Optional budget → planned transaction via ExpenseLinkService-style call into the transactions table (trip_id set).
TESTS: tag write/reconcile/cancel (never touching manual tags), packing list created once, budget transaction lifecycle.

Step 2 — Trip UI (commit: "feat(trips): planner screens")
More entry "Travel Planner": upcoming + probable + history sections; trip detail (dates, location, description, links list, images via ImageService, packing list tap-through, budget); probable plans interplay — a 'probable' template item (Agent 2) can be promoted into a trip (action wired if list engine present; otherwise expose promoteFromTitle API). Calendar: final trips render as range bars (already supported by aggregator — verify and test).
TESTS: widget tests for create/promote/finalize flows; calendar bar rendering test.

Step 3 — Reminders (commit: "feat(reminders): windowed reminders")
More entry "Reminders": CRUD (title, description, window start/end, priority, notify rule — e.g. on window start + every N days while open). Active-window reminders appear as banner on the main calendar and a card on Today. Done/dismissed states.
TESTS: window-active computation, notification scheduling per rule (fake service), banner rendering.

Step 4 — Partner schedule (commit: "feat(partner): partner overlay")
More entry "Partner Schedule": manage partner-owned tags and events (owner='partner') — availability days, exam/deadline events, weekly repeats via RRULE. Verify the thin partner strip renders in main-calendar cells and the day sheet shows a partner section. Settings toggle to show/hide partner layer.
TESTS: partner data isolated from 'me' queries, strip rendering, toggle filter.

Step 5 — Conflict engine (commit: "feat(conflicts): rule engine v1")
Implement ConflictEngine in lib/core/conflicts implementing the ConflictFeed interface Agent 1 defined for Today. Evaluated on day_tag and gym_session changes (drift watch). Rules v1:
  R1: 'travel' tag on a date with a planned gym_session → suggestion "move or skip session" with one-tap actions (move to next non-travel day with same weekday preference, or mark skipped).
  R2: final trip overlapping an event owned by 'me' → informational flag.
  R3: 'travel' tag on a date with accepted meal_slots → suggest clearing those slots.
Suggestions are dismissible cards on Today — NEVER auto-modify data; every action is user-confirmed. Architecture must make adding a rule ≈ one class + tests.
TESTS: each rule unit-tested (fires, doesn't fire, action applies correctly, dismissal persists).

Step 6 — Recipes & ingredients (commit: "feat(meals): recipe data layer")
Repositories over ingredients/recipes/recipe_ingredients: CRUD, tag filtering, search. Recipe editor UI: name, slot, prep minutes, tag multi-select (quick, prep-ahead, high-protein, reza-shared, needs-oven + custom), ingredient rows (ingredient autocomplete-or-create, amount, unit), optional image, instructions. Macros columns exist but are hidden in v1 UI. Seed NOTHING — owner provides recipes later.
TESTS: CRUD, tag filter queries, ingredient dedup on autocomplete-create.

Step 7 — Suggestion algorithm (commit: "feat(meals): weekly suggestions")
Pure, fully unit-testable MealSuggester: input = 7 days of day_tags + recipe pool + recent meal history; constraints from design.md 4.4 (gym→high-protein dinner + post-gym-shake slot, work→prep-ahead/quick lunch, reza/linz→prefer reza-shared, no repeat within 3 days incl. previous week's tail); random pick among valid (injectable seed for tests); per-slot fallback when no recipe matches a constraint → relax preference-level constraints first, hard constraints produce an explicit "no match" the UI shows honestly.
TESTS: every constraint individually, combined-tags day, empty pool, fallback ordering, determinism under fixed seed, no-repeat window across week boundary.

Step 8 — Weekly flow + meal UI (commit: "feat(meals): week grid and Sunday flow")
Track entry "Meals": week grid (7 days × slots) showing day-tag icons per column; "Plan next week" flow — confirm/edit next week's day tags (writes day_tags), generate suggestions, swap any cell from its valid pool, accept week (slots → accepted). Sunday evening notification triggers this flow. Mark eaten/skipped from Today/day sheet. Calendar dots via aggregator under "Meals" chip.
TESTS: widget tests for grid render, swap respects constraints, accept persists; scheduling test for the Sunday notification.

Step 9 — Shopping generation (commit: "feat(meals): shopping list generation")
On accepting a week: aggregate recipe_ingredients across accepted slots, sum amounts per ingredient (unit-aware: only sum identical units, otherwise list separately), group by ingredient category, write items into a "Groceries — week of <date>" collection (shopping template). Regenerating for the same week updates rather than duplicates. Bought flow connects to ExpenseLinkService if present.
TESTS: aggregation math (amount summing, mixed-unit separation), grouping, regeneration idempotency.

DEFINITION OF DONE: analyze + tests green; on emulator: create a final trip → travel tags appear → planned gym session on that date raises a conflict card → meal plan week excludes/clears travel days → accepted week generates a grocery list. That end-to-end chain IS the product — record it working before merging to main (last merge).
```

---

## Part C — After all merges

```bash
git checkout main
flutter analyze && flutter test          # full suite green
flutter run                              # full manual pass on emulator
git tag v1.0.0-alpha
flutter build apk --release              # install on your real phone
```

Then: live in the app for 2 weeks before adding anything, fill in your real data (recipes, gym plans A/B/C, subscriptions, company lists), and keep a "v2" list inside the app itself.
